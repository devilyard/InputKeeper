//
//  InputMethodStore.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import Foundation

final class InputMethodStore {
    private enum Key {
        static let preferences = "applicationInputPreferences"
        static let isMonitoringEnabled = "isMonitoringEnabled"
    }

    private let defaults: UserDefaults
    private var preferencesByBundleIdentifier: [String: ApplicationInputPreference]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferencesByBundleIdentifier = Self.loadPreferences(from: defaults)
    }

    var preferences: [ApplicationInputPreference] {
        preferencesByBundleIdentifier.values.sorted {
            $0.applicationName.localizedStandardCompare($1.applicationName) == .orderedAscending
        }
    }

    var isMonitoringEnabled: Bool {
        guard defaults.object(forKey: Key.isMonitoringEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: Key.isMonitoringEnabled)
    }

    func preference(for bundleIdentifier: String) -> ApplicationInputPreference? {
        preferencesByBundleIdentifier[bundleIdentifier]
    }

    func save(_ preference: ApplicationInputPreference) {
        preferencesByBundleIdentifier = Self.loadPreferences(from: defaults)
        preferencesByBundleIdentifier[preference.bundleIdentifier] = preference
        persistPreferences()
    }

    func removePreference(for bundleIdentifier: String) {
        preferencesByBundleIdentifier = Self.loadPreferences(from: defaults)
        preferencesByBundleIdentifier.removeValue(forKey: bundleIdentifier)
        persistPreferences()
    }

    func setMonitoringEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Key.isMonitoringEnabled)
    }

    private static func loadPreferences(from defaults: UserDefaults) -> [String: ApplicationInputPreference] {
        guard
            let data = defaults.data(forKey: Key.preferences),
            let storedPreferences = try? JSONDecoder().decode([ApplicationInputPreference].self, from: data)
        else {
            return [:]
        }

        return Dictionary(storedPreferences.map { ($0.bundleIdentifier, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func persistPreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: Key.preferences)
    }
}
