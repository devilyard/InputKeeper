//
//  InputKeeperApp.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

@preconcurrency import AppKit
import SwiftUI

@main
struct InputKeeperApp: App {
    @StateObject private var coordinator: InputMethodCoordinator

    init() {
        Self.terminateOtherInstances()
        _coordinator = StateObject(wrappedValue: InputMethodCoordinator())
    }

    var body: some Scene {
        MenuBarExtra {
            InputKeeperMenu(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.isEnabled ? "keyboard.badge.eye" : "keyboard")
        }
        .menuBarExtraStyle(.menu)
    }

    private static func terminateOtherInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).filter {
            $0.processIdentifier != currentProcessIdentifier
        }

        for instance in otherInstances {
            instance.terminate()
        }

        waitForTermination(of: otherInstances, timeout: 0.5)

        let remainingInstances = otherInstances.filter { !$0.isTerminated }
        for instance in remainingInstances {
            instance.forceTerminate()
        }

        waitForTermination(of: remainingInstances, timeout: 0.5)
    }

    private static func waitForTermination(of applications: [NSRunningApplication], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while applications.contains(where: { !$0.isTerminated }), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
    }
}
