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

    func testStoreMergesPreferencesSavedByAnotherInstance() {
        let firstStore = InputMethodStore(defaults: defaults)
        let secondStore = InputMethodStore(defaults: defaults)
        let firstPreference = makePreference(
            bundleIdentifier: "com.example.first",
            applicationName: "第一个应用",
            inputSourceName: "鼠须管"
        )
        let secondPreference = makePreference(
            bundleIdentifier: "com.example.second",
            applicationName: "第二个应用",
            inputSourceID: "abc",
            inputSourceName: "ABC"
        )

        firstStore.save(firstPreference)
        secondStore.save(secondPreference)

        let reloadedStore = InputMethodStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.preference(for: firstPreference.bundleIdentifier), firstPreference)
        XCTAssertEqual(reloadedStore.preference(for: secondPreference.bundleIdentifier), secondPreference)
    }

    func testAutomaticInputSourceChangeIsSuppressedDuringProtectionInterval() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        filter.begin(at: startDate)

        XCTAssertTrue(filter.shouldSuppressChange(at: startDate.addingTimeInterval(0.49)))
    }

    func testInputSourceChangeIsAcceptedAfterProtectionInterval() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        filter.begin(at: startDate)

        XCTAssertFalse(filter.shouldSuppressChange(at: startDate.addingTimeInterval(0.5)))
        XCTAssertFalse(filter.shouldSuppressChange(at: startDate.addingTimeInterval(0.51)))
    }

    func testStartingAnotherAutomaticChangeExtendsProtectionInterval() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        filter.begin(at: startDate)
        filter.begin(at: startDate.addingTimeInterval(0.4))

        XCTAssertTrue(filter.shouldSuppressChange(at: startDate.addingTimeInterval(0.8)))
        XCTAssertFalse(filter.shouldSuppressChange(at: startDate.addingTimeInterval(0.9)))
    }

    private func makePreference(
        bundleIdentifier: String = "com.example.application",
        applicationName: String,
        inputSourceID: String = "test.input-source",
        inputSourceName: String
    ) -> ApplicationInputPreference {
        ApplicationInputPreference(
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            inputSourceID: inputSourceID,
            inputSourceName: inputSourceName
        )
    }
}
