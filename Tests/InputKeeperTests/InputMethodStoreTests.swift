//
//  InputMethodStoreTests.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import XCTest
@testable import InputKeeper

final class InputMethodStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "InputMethodStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewStoreEnablesMonitoringByDefault() {
        let store = InputMethodStore(defaults: defaults)

        XCTAssertTrue(store.isMonitoringEnabled)
    }

    func testPreferencePersistsAcrossStoreInstances() {
        let preference = makePreference(applicationName: "写作", inputSourceName: "拼音")
        let store = InputMethodStore(defaults: defaults)

        store.save(preference)

        let reloadedStore = InputMethodStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.preference(for: preference.bundleIdentifier), preference)
    }

    func testSavingSameApplicationReplacesItsInputSource() {
        let store = InputMethodStore(defaults: defaults)
        store.save(makePreference(applicationName: "写作", inputSourceID: "pinyin", inputSourceName: "拼音"))

        let updatedPreference = makePreference(applicationName: "写作", inputSourceID: "abc", inputSourceName: "ABC")
        store.save(updatedPreference)

        XCTAssertEqual(store.preferences, [updatedPreference])
    }

    func testRemovePreferencePersists() {
        let preference = makePreference(applicationName: "终端", inputSourceName: "ABC")
        let store = InputMethodStore(defaults: defaults)
        store.save(preference)

        store.removePreference(for: preference.bundleIdentifier)

        XCTAssertNil(InputMethodStore(defaults: defaults).preference(for: preference.bundleIdentifier))
    }

    private func makePreference(
        applicationName: String,
        inputSourceID: String = "test.input-source",
        inputSourceName: String
    ) -> ApplicationInputPreference {
        ApplicationInputPreference(
            bundleIdentifier: "com.example.application",
            applicationName: applicationName,
            inputSourceID: inputSourceID,
            inputSourceName: inputSourceName
        )
    }
}
