//
//  InputKeeperMenu.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import AppKit
import SwiftUI

struct InputKeeperMenu: View {
    @ObservedObject var coordinator: InputMethodCoordinator

    var body: some View {
        Toggle(
            "启用自动切换",
            isOn: Binding(
                get: { coordinator.isEnabled },
                set: { coordinator.setEnabled($0) }
            )
        )

        Divider()

        Text("\(coordinator.currentApplicationName) · \(coordinator.currentInputSourceName)")

        if let statusMessage = coordinator.statusMessage {
            Text(statusMessage)
        }

        if coordinator.rememberedApplications.isEmpty {
            Text("切换输入法后会自动记住")
        } else {
            Divider()
            Menu("已记住 \(coordinator.rememberedApplications.count) 个应用") {
                ForEach(coordinator.rememberedApplications) { preference in
                    Menu("\(preference.applicationName) · \(preference.inputSourceName)") {
                        Text(preference.bundleIdentifier)
                        Button("忘记此记录") {
                            coordinator.forget(preference)
                        }
                    }
                }
            }
        }

        Divider()

        Button("退出 InputKeeper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
