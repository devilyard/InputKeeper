//
//  InputMethodCoordinator.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

@preconcurrency import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import OSLog

struct AutomaticInputSourceChangeFilter {
    private let protectionInterval: TimeInterval
    private var suppressionDeadline: Date?

    init(protectionInterval: TimeInterval = 0.5) {
        self.protectionInterval = protectionInterval
    }

    mutating func begin(at date: Date = Date()) {
        suppressionDeadline = date.addingTimeInterval(protectionInterval)
    }

    mutating func cancel() {
        suppressionDeadline = nil
    }

    mutating func shouldSuppressChange(at date: Date = Date()) -> Bool {
        guard let suppressionDeadline else {
            return false
        }

        guard date < suppressionDeadline else {
            self.suppressionDeadline = nil
            return false
        }

        return true
    }
}

@MainActor
final class InputMethodCoordinator: NSObject, ObservableObject {
    private struct ActiveApplication {
        let bundleIdentifier: String
        let name: String
    }

    @Published private(set) var rememberedApplications: [ApplicationInputPreference]
    @Published private(set) var isEnabled: Bool
    @Published private(set) var currentApplicationName = L10n.string("status.waiting_for_frontmost_application")
    @Published private(set) var currentInputSourceName = L10n.string("status.unknown_input_source")
    @Published private(set) var statusMessage: String?

    private let store: InputMethodStore
    private let inputSourceManager: InputSourceManaging
    private let workspace: NSWorkspace
    private let ownBundleIdentifier: String
    private let logger = Logger(subsystem: "com.typhoon.InputKeeper", category: "Coordinator")
    private var workspaceObserver: NSObjectProtocol?
    private var keyboardSelectionObserver: NSObjectProtocol?
    private var inputSourcePollingTimer: Timer?
    private var activationTask: Task<Void, Never>?
    private var pendingActivationBundleIdentifier: String?
    private var automaticInputSourceChangeFilter = AutomaticInputSourceChangeFilter()
    private var activeBundleIdentifier: String?
    private var lastObservedInputSourceID: String?

    init(
        store: InputMethodStore = InputMethodStore(),
        inputSourceManager: InputSourceManaging = SystemInputSourceManager(),
        workspace: NSWorkspace = .shared,
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.typhoon.InputKeeper"
    ) {
        self.store = store
        self.inputSourceManager = inputSourceManager
        self.workspace = workspace
        self.ownBundleIdentifier = ownBundleIdentifier
        rememberedApplications = store.preferences
        isEnabled = store.isMonitoringEnabled

        super.init()
        startMonitoring()
    }

    func setEnabled(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }

        self.isEnabled = isEnabled
        store.setMonitoringEnabled(isEnabled)
        statusMessage = isEnabled ? nil : L10n.string("status.auto_switch_paused")

        if isEnabled {
            synchronizeWithFrontmostApplication()
        } else {
            activationTask?.cancel()
            activationTask = nil
            pendingActivationBundleIdentifier = nil
            automaticInputSourceChangeFilter.cancel()
        }
    }

    func forget(_ preference: ApplicationInputPreference) {
        store.removePreference(for: preference.bundleIdentifier)
        reloadPreferences()
        statusMessage = L10n.string("status.forgot_input_method", preference.applicationName)
    }

    func forgetAll() {
        store.removeAllPreferences()
        reloadPreferences()
        statusMessage = L10n.string("status.forgot_all_input_methods")
    }

    private func startMonitoring() {
        workspaceObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handleApplicationActivation(application)
            }
        }

        let notificationName = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange(_:)),
            name: notificationName,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        keyboardSelectionObserver = NotificationCenter.default.addObserver(
            forName: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInputSourceChange()
            }
        }

        synchronizeWithFrontmostApplication()
        startInputSourcePolling()
    }

    @objc
    private nonisolated func inputSourceDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.handleInputSourceChange()
        }
    }

    private func synchronizeWithFrontmostApplication() {
        guard let application = workspace.frontmostApplication else {
            return
        }
        handleApplicationActivation(application)
    }

    private func startInputSourcePolling() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollInputSource()
            }
        }
        inputSourcePollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pollInputSource() {
        guard
            isEnabled,
            let runningApplication = workspace.frontmostApplication,
            let application = descriptor(for: runningApplication)
        else {
            return
        }

        guard activeBundleIdentifier == application.bundleIdentifier else {
            handleApplicationActivation(runningApplication)
            return
        }

        guard
            let currentInputSource = inputSourceManager.currentInputSource(),
            currentInputSource.id != lastObservedInputSourceID
        else {
            return
        }

        handleInputSourceChange(currentInputSource)
    }

    private func handleApplicationActivation(_ application: NSRunningApplication) {
        guard
            isEnabled,
            let activeApplication = descriptor(for: application),
            workspace.frontmostApplication?.bundleIdentifier == activeApplication.bundleIdentifier
        else {
            return
        }

        activationTask?.cancel()
        activeBundleIdentifier = activeApplication.bundleIdentifier
        pendingActivationBundleIdentifier = activeApplication.bundleIdentifier
        currentApplicationName = activeApplication.name

        if let currentInputSource = inputSourceManager.currentInputSource() {
            lastObservedInputSourceID = currentInputSource.id
            currentInputSourceName = currentInputSource.name
        }

        activationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else {
                return
            }

            self?.completeApplicationActivation(activeApplication)
        }
    }

    private func completeApplicationActivation(_ activeApplication: ActiveApplication) {
        guard
            isEnabled,
            activeBundleIdentifier == activeApplication.bundleIdentifier,
            pendingActivationBundleIdentifier == activeApplication.bundleIdentifier,
            workspace.frontmostApplication?.bundleIdentifier == activeApplication.bundleIdentifier
        else {
            return
        }

        activationTask = nil
        pendingActivationBundleIdentifier = nil

        guard let currentInputSource = inputSourceManager.currentInputSource() else {
            statusMessage = L10n.string("status.unable_to_read_current_input_source")
            return
        }

        logger.debug(
            "处理应用激活：应用=\(activeApplication.bundleIdentifier, privacy: .public)，当前输入源=\(currentInputSource.id, privacy: .public)"
        )

        lastObservedInputSourceID = currentInputSource.id
        currentInputSourceName = currentInputSource.name

        guard let preference = store.preference(for: activeApplication.bundleIdentifier) else {
            remember(currentInputSource, for: activeApplication)
            return
        }

        guard preference.inputSourceID != currentInputSource.id else {
            statusMessage = nil
            return
        }

        logger.info(
            "恢复应用输入源：应用=\(activeApplication.bundleIdentifier, privacy: .public)，目标=\(preference.inputSourceID, privacy: .public)"
        )

        automaticInputSourceChangeFilter.begin()

        guard inputSourceManager.selectInputSource(withID: preference.inputSourceID) else {
            automaticInputSourceChangeFilter.cancel()
            statusMessage = L10n.string("status.unable_to_switch_input_source", preference.inputSourceName)
            return
        }

        currentInputSourceName = inputSourceManager.inputSourceName(for: preference.inputSourceID) ?? preference.inputSourceName
        statusMessage = nil
    }

    private func handleInputSourceChange(_ observedInputSource: InputSourceDescriptor? = nil) {
        guard
            isEnabled,
            let runningApplication = workspace.frontmostApplication,
            let activeApplication = descriptor(for: runningApplication)
        else {
            return
        }

        guard activeBundleIdentifier == activeApplication.bundleIdentifier else {
            handleApplicationActivation(runningApplication)
            return
        }

        guard let currentInputSource = observedInputSource ?? inputSourceManager.currentInputSource() else {
            return
        }

        lastObservedInputSourceID = currentInputSource.id
        currentApplicationName = activeApplication.name
        currentInputSourceName = currentInputSource.name

        guard pendingActivationBundleIdentifier != activeApplication.bundleIdentifier else {
            return
        }

        if automaticInputSourceChangeFilter.shouldSuppressChange() {
            restoreRememberedInputSourceIfNeeded(currentInputSource, for: activeApplication)
            return
        }

        remember(currentInputSource, for: activeApplication)
    }

    private func restoreRememberedInputSourceIfNeeded(
        _ currentInputSource: InputSourceDescriptor,
        for activeApplication: ActiveApplication
    ) {
        guard
            let preference = store.preference(for: activeApplication.bundleIdentifier),
            preference.inputSourceID != currentInputSource.id
        else {
            statusMessage = nil
            return
        }

        automaticInputSourceChangeFilter.begin()
        guard inputSourceManager.selectInputSource(withID: preference.inputSourceID) else {
            automaticInputSourceChangeFilter.cancel()
            statusMessage = L10n.string("status.unable_to_switch_input_source", preference.inputSourceName)
            return
        }

        currentInputSourceName = inputSourceManager.inputSourceName(for: preference.inputSourceID) ?? preference.inputSourceName
        statusMessage = nil
    }

    private func descriptor(for application: NSRunningApplication) -> ActiveApplication? {
        guard
            let bundleIdentifier = application.bundleIdentifier,
            bundleIdentifier != ownBundleIdentifier
        else {
            return nil
        }

        let name = application.localizedName ?? bundleIdentifier
        return ActiveApplication(bundleIdentifier: bundleIdentifier, name: name)
    }

    private func remember(_ inputSource: InputSourceDescriptor, for application: ActiveApplication) {
        let preference = ApplicationInputPreference(
            bundleIdentifier: application.bundleIdentifier,
            applicationName: application.name,
            inputSourceID: inputSource.id,
            inputSourceName: inputSource.name
        )

        guard store.preference(for: application.bundleIdentifier) != preference else {
            return
        }

        store.save(preference)
        reloadPreferences()
        statusMessage = L10n.string("status.remembered_input_source", application.name, inputSource.name)
    }

    private func reloadPreferences() {
        rememberedApplications = store.preferences
    }
}
