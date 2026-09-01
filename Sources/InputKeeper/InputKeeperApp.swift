//
//  InputKeeperApp.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import SwiftUI

@main
struct InputKeeperApp: App {
    @StateObject private var coordinator = InputMethodCoordinator()

    var body: some Scene {
        MenuBarExtra {
            InputKeeperMenu(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.isEnabled ? "keyboard.badge.eye" : "keyboard")
        }
        .menuBarExtraStyle(.menu)
    }
}
