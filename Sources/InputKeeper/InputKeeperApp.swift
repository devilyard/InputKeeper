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
        _coordinator = StateObject(wrappedValue: InputMethodCoordinator())
    }

    var body: some Scene {
        MenuBarExtra {
            InputKeeperMenu(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.isEnabled ? "keyboard.badge.eye" : "keyboard")
        }
        .menuBarExtraStyle(.menu)

        Window(L10n.string("help.title"), id: InputKeeperWindow.help) {
            InputKeeperHelpView()
        }
        .defaultSize(width: 520, height: 420)

        Window(L10n.string("privacy.title"), id: InputKeeperWindow.privacyPolicy) {
            PrivacyPolicyView()
        }
        .defaultSize(width: 560, height: 540)

        Window(L10n.string("support.title"), id: InputKeeperWindow.technicalSupport) {
            TechnicalSupportView()
        }
        .defaultSize(width: 520, height: 420)
    }
}
