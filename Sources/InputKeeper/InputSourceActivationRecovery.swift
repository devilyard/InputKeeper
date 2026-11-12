//
//  InputSourceActivationRecovery.swift
//  InputKeeper
//
//  Created by Codex on 2026/11/5.
//

@preconcurrency import AppKit
import Carbon.HIToolbox
import Foundation
import OSLog

struct InputSourceActivationRecoveryPolicy {
    static func shouldRecover(
        previousSourceType: String?,
        targetSourceType: String?,
        targetLanguages: [String]
    ) -> Bool {
        guard
            previousSourceType == kTISTypeKeyboardLayout as String,
            targetSourceType == kTISTypeKeyboardInputMode as String
        else {
            return false
        }

        return targetLanguages.contains(where: isCJKVLanguage)
    }

    private static func isCJKVLanguage(_ language: String) -> Bool {
        let normalizedLanguage = language.lowercased()
        return normalizedLanguage == "ja"
            || normalizedLanguage == "ko"
            || normalizedLanguage == "vi"
            || normalizedLanguage.hasPrefix("zh")
    }
}

@MainActor
protocol InputSourceActivationRecovering: AnyObject {
    func recoverFocus(returningTo application: NSRunningApplication)
}

@MainActor
final class SystemInputSourceActivationRecovery: InputSourceActivationRecovering {
    private static let recoveryDelay: Duration = .milliseconds(150)

    private let logger = Logger(subsystem: "com.typhoon.InputKeeper", category: "InputSourceActivation")
    private var recoveryTask: Task<Void, Never>?
    private var recoveryPanel: NSPanel?
    private var recoveryIdentifier = UUID()

    func recoverFocus(returningTo application: NSRunningApplication) {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard application.processIdentifier != ownProcessIdentifier else {
            return
        }

        recoveryTask?.cancel()
        dismissRecoveryPanel()

        let identifier = UUID()
        recoveryIdentifier = identifier
        let targetProcessIdentifier = application.processIdentifier

        recoveryTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let panel = makeRecoveryPanel()
            recoveryPanel = panel
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.contentView)

            // TISSelectInputSource can leave an input method selected while
            // InputMethodKit no longer routes keystrokes to its controller.
            // A real application activation round trip repairs that state.
            // This uses only public AppKit APIs so it remains sandbox-safe.
            NSApplication.shared.activate(ignoringOtherApps: true)

            do {
                try await Task.sleep(for: Self.recoveryDelay)
            } catch {
                finishRecovery(identifier: identifier, returningTo: nil)
                return
            }

            guard recoveryIdentifier == identifier else {
                return
            }

            guard NSApplication.shared.isActive else {
                logger.debug(
                    "用户在输入源激活恢复期间切换了应用，不再恢复旧应用焦点：目标进程=\(targetProcessIdentifier)"
                )
                finishRecovery(identifier: identifier, returningTo: nil)
                return
            }

            let targetApplication = NSRunningApplication(processIdentifier: targetProcessIdentifier)
            finishRecovery(identifier: identifier, returningTo: targetApplication)
        }
    }

    private func finishRecovery(identifier: UUID, returningTo application: NSRunningApplication?) {
        guard recoveryIdentifier == identifier else {
            return
        }

        dismissRecoveryPanel()
        recoveryTask = nil

        guard let application, !application.isTerminated else {
            return
        }

        let didActivate = application.activate(options: [.activateIgnoringOtherApps])
        logger.info(
            "完成输入源激活恢复：目标进程=\(application.processIdentifier)，应用重新激活=\(didActivate)"
        )
    }

    private func dismissRecoveryPanel() {
        recoveryPanel?.orderOut(nil)
        recoveryPanel = nil
    }

    private func makeRecoveryPanel() -> NSPanel {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panel = InputSourceRecoveryPanel(
            contentRect: NSRect(
                x: screenFrame.maxX - 1,
                y: screenFrame.minY,
                width: 1,
                height: 1
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.alphaValue = 0.01
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        panel.contentView = inputField
        panel.initialFirstResponder = inputField
        return panel
    }
}

private final class InputSourceRecoveryPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
