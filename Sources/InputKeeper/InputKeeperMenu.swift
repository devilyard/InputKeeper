//
//  InputKeeperMenu.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import AppKit
import SwiftUI

enum L10n {
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}

enum InputKeeperWindow {
    static let help = "help"
    static let privacyPolicy = "privacy-policy"
    static let technicalSupport = "technical-support"
}

struct InputKeeperMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var coordinator: InputMethodCoordinator

    var body: some View {
        Toggle(
            L10n.string("menu.enable_auto_switch"),
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
            Text(L10n.string("menu.remember_after_switching"))
        } else {
            Divider()
            Menu(L10n.string("menu.remembered_applications", coordinator.rememberedApplications.count)) {
                ForEach(coordinator.rememberedApplications) { preference in
                    Menu("\(preference.applicationName) · \(preference.inputSourceName)") {
                        Text(preference.bundleIdentifier)
                        Button(L10n.string("menu.forget_record")) {
                            coordinator.forget(preference)
                        }
                    }
                }

                Divider()

                Button(L10n.string("menu.forget_all_records"), role: .destructive) {
                    coordinator.forgetAll()
                }
            }
        }

        Divider()

        Button(L10n.string("menu.about")) {
            NSApplication.shared.orderFrontStandardAboutPanel(nil)
            activateApplication()
        }

        Button(L10n.string("menu.help")) {
            openWindow(id: InputKeeperWindow.help)
            activateApplication()
        }

        Button(L10n.string("menu.privacy_policy")) {
            openWindow(id: InputKeeperWindow.privacyPolicy)
            activateApplication()
        }

        Button(L10n.string("menu.technical_support")) {
            openWindow(id: InputKeeperWindow.technicalSupport)
            activateApplication()
        }

        Divider()

        Button(L10n.string("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func activateApplication() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

struct InputKeeperHelpView: View {
    var body: some View {
        InformationView(title: L10n.string("help.title")) {
            InformationSection(
                title: L10n.string("help.how_it_works.title"),
                text: L10n.string("help.how_it_works.body")
            )
            InformationSection(
                title: L10n.string("help.controls.title"),
                text: L10n.string("help.controls.body")
            )
            InformationSection(
                title: L10n.string("help.permissions.title"),
                text: L10n.string("help.permissions.body")
            )
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        InformationView(title: L10n.string("privacy.title")) {
            Text(L10n.string("privacy.updated"))
                .font(.caption)
                .foregroundStyle(.secondary)

            InformationSection(
                title: L10n.string("privacy.local_data.title"),
                text: L10n.string("privacy.local_data.body")
            )
            InformationSection(
                title: L10n.string("privacy.no_collection.title"),
                text: L10n.string("privacy.no_collection.body")
            )
            InformationSection(
                title: L10n.string("privacy.retention.title"),
                text: L10n.string("privacy.retention.body")
            )
            InformationSection(
                title: L10n.string("privacy.support.title"),
                text: L10n.string("privacy.support.body")
            )
        }
    }
}

struct TechnicalSupportView: View {
    var body: some View {
        InformationView(title: L10n.string("support.title")) {
            InformationSection(
                title: L10n.string("support.troubleshooting.title"),
                text: L10n.string("support.troubleshooting.body")
            )
            InformationSection(
                title: L10n.string("support.diagnostics.title"),
                text: L10n.string("support.diagnostics.body")
            )
            InformationSection(
                title: L10n.string("support.contact.title"),
                text: L10n.string("support.contact.body")
            )
        }
    }
}

private struct InformationView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(minWidth: 440, minHeight: 340)
    }
}

private struct InformationSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
