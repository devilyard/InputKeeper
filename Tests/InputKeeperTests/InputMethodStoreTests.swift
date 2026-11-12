//
//  InputMethodStoreTests.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import Carbon.HIToolbox
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

    func testRemoveAllPreferencesPersists() {
        let store = InputMethodStore(defaults: defaults)
        store.save(makePreference(bundleIdentifier: "com.example.first", applicationName: "写作", inputSourceName: "拼音"))
        store.save(makePreference(bundleIdentifier: "com.example.second", applicationName: "终端", inputSourceName: "ABC"))

        store.removeAllPreferences()

        XCTAssertTrue(store.preferences.isEmpty)
        XCTAssertTrue(InputMethodStore(defaults: defaults).preferences.isEmpty)
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

    func testActivationRestoresRememberedInputSourceWhenDifferent() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        XCTAssertEqual(
            filter.applicationDidActivate(
                bundleIdentifier: "com.openai.codex",
                rememberedInputSourceID: "rime",
                currentInputSourceID: "abc",
                at: startDate
            ),
            .restore
        )
    }

    func testActivationAlreadyUsingRimeStillRestoresDelayedEnglishFallback() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        XCTAssertEqual(
            filter.applicationDidActivate(
                bundleIdentifier: "com.openai.codex",
                rememberedInputSourceID: "rime",
                currentInputSourceID: "rime",
                at: startDate
            ),
            .none
        )

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.49)),
            .restore
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "rime", in: "com.openai.codex", at: startDate.addingTimeInterval(0.49)),
            .none
        )
    }

    func testFocusRecoveryReturnStartsFreshProtectionEvenWhenSourceMatches() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)

        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "abc",
            at: startDate
        )
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate.addingTimeInterval(0.6)
        )

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.8)),
            .restore
        )
    }

    func testChangesAreRememberedAfterProtectionExpires() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate
        )

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.5)),
            .remember
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.51)),
            .remember
        )
    }

    func testRestoringFallbackProtectsFollowupChangesForAFullInterval() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate
        )

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.4)),
            .restore
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.8)),
            .restore
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(1.3)),
            .remember
        )
    }

    func testRapidActivationUsesTheNewApplicationsPreference() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate
        )
        XCTAssertEqual(
            filter.applicationDidActivate(
                bundleIdentifier: "com.example.editor",
                rememberedInputSourceID: "abc",
                currentInputSourceID: "rime",
                at: startDate.addingTimeInterval(0.1)
            ),
            .restore
        )

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.example.editor", at: startDate.addingTimeInterval(0.2)),
            .none
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.2)),
            .remember
        )
    }

    func testFirstVisitRemembersCurrentInputSourceWithoutPreviousApplicationsProtection() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate
        )

        XCTAssertEqual(
            filter.applicationDidActivate(
                bundleIdentifier: "com.example.new",
                rememberedInputSourceID: nil,
                currentInputSourceID: "abc",
                at: startDate.addingTimeInterval(0.1)
            ),
            .remember
        )
        XCTAssertEqual(
            filter.inputSourceDidChange(to: "rime", in: "com.example.new", at: startDate.addingTimeInterval(0.2)),
            .remember
        )
    }

    func testCancellingProtectionAllowsInputSourceChangesToBeRemembered() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var filter = AutomaticInputSourceChangeFilter(protectionInterval: 0.5)
        _ = filter.applicationDidActivate(
            bundleIdentifier: "com.openai.codex",
            rememberedInputSourceID: "rime",
            currentInputSourceID: "rime",
            at: startDate
        )

        filter.cancel()

        XCTAssertEqual(
            filter.inputSourceDidChange(to: "abc", in: "com.openai.codex", at: startDate.addingTimeInterval(0.1)),
            .remember
        )
    }

    func testSuccessfulInputSourceSelectionDoesNotEnableParent() {
        XCTAssertFalse(
            InputSourceParentRetryPolicy.shouldRetry(
                initialStatus: noErr,
                sourceType: kTISTypeKeyboardInputMode as String
            )
        )
    }

    func testInvalidInputModeSelectionRetriesAfterEnablingParent() {
        XCTAssertTrue(
            InputSourceParentRetryPolicy.shouldRetry(
                initialStatus: OSStatus(paramErr),
                sourceType: kTISTypeKeyboardInputMode as String
            )
        )
    }

    func testInvalidKeyboardLayoutSelectionDoesNotEnableParent() {
        XCTAssertFalse(
            InputSourceParentRetryPolicy.shouldRetry(
                initialStatus: OSStatus(paramErr),
                sourceType: kTISTypeKeyboardLayout as String
            )
        )
    }

    func testCJKVInputModeSelectedFromKeyboardLayoutRequiresActivationRecovery() {
        XCTAssertTrue(
            InputSourceActivationRecoveryPolicy.shouldRecover(
                previousSourceType: kTISTypeKeyboardLayout as String,
                targetSourceType: kTISTypeKeyboardInputMode as String,
                targetLanguages: ["zh-Hans"]
            )
        )
    }

    func testCJKVInputModeSelectedFromAnotherInputModeDoesNotRequireActivationRecovery() {
        XCTAssertFalse(
            InputSourceActivationRecoveryPolicy.shouldRecover(
                previousSourceType: kTISTypeKeyboardInputMode as String,
                targetSourceType: kTISTypeKeyboardInputMode as String,
                targetLanguages: ["zh-Hans"]
            )
        )
    }

    func testLatinInputModeDoesNotRequireActivationRecovery() {
        XCTAssertFalse(
            InputSourceActivationRecoveryPolicy.shouldRecover(
                previousSourceType: kTISTypeKeyboardLayout as String,
                targetSourceType: kTISTypeKeyboardInputMode as String,
                targetLanguages: ["en"]
            )
        )
    }

    func testKeyboardLayoutTargetDoesNotRequireActivationRecovery() {
        XCTAssertFalse(
            InputSourceActivationRecoveryPolicy.shouldRecover(
                previousSourceType: kTISTypeKeyboardLayout as String,
                targetSourceType: kTISTypeKeyboardLayout as String,
                targetLanguages: ["zh-Hans"]
            )
        )
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
