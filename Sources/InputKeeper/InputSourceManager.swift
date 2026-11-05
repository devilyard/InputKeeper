//
//  InputSourceManager.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import Carbon.HIToolbox
import Foundation
import OSLog

struct InputSourceDescriptor: Equatable {
    let id: String
    let name: String
}

struct InputSourceParentRetryPolicy {
    static func shouldRetry(initialStatus: OSStatus, sourceType: String?) -> Bool {
        initialStatus == paramErr && sourceType == kTISTypeKeyboardInputMode as String
    }
}

protocol InputSourceManaging: AnyObject {
    func currentInputSource() -> InputSourceDescriptor?
    func inputSourceName(for id: String) -> String?
    func selectInputSource(withID id: String) -> Bool
}

final class SystemInputSourceManager: InputSourceManaging {
    private let logger = Logger(subsystem: "com.typhoon.InputKeeper", category: "InputSource")

    func currentInputSource() -> InputSourceDescriptor? {
        guard let unmanagedSource = TISCopyCurrentKeyboardInputSource() else {
            return nil
        }
        return descriptor(for: unmanagedSource.takeRetainedValue())
    }

    func inputSourceName(for id: String) -> String? {
        inputSource(withID: id).flatMap { descriptor(for: $0)?.name }
    }

    func selectInputSource(withID id: String) -> Bool {
        guard let source = inputSource(withID: id) else {
            logger.error("找不到输入源：\(id, privacy: .public)")
            return false
        }

        guard validateForSelection(source) else {
            return false
        }

        let initialStatus = TISSelectInputSource(source)
        if initialStatus == noErr {
            logSelection(id: id, status: initialStatus, isRetry: false)
            return true
        }

        let sourceType = stringProperty(kTISPropertyInputSourceType, of: source)
        guard
            InputSourceParentRetryPolicy.shouldRetry(initialStatus: initialStatus, sourceType: sourceType),
            let parent = parentInputSource(for: source),
            enableParentIfNeeded(parent, childID: id)
        else {
            logSelection(id: id, status: initialStatus, isRetry: false)
            return false
        }

        let retryStatus = TISSelectInputSource(source)
        logSelection(id: id, status: retryStatus, isRetry: true)
        return retryStatus == noErr
    }

    private func logSelection(id: String, status: OSStatus, isRetry: Bool) {
        let currentID = currentInputSource()?.id ?? "未知"
        logger.info(
            "切换输入源：目标=\(id, privacy: .public)，重试=\(isRetry)，状态码=\(status)，当前=\(currentID, privacy: .public)"
        )
        if status != noErr {
            logger.error("切换输入源失败：\(id, privacy: .public)，状态码：\(status)")
        }
    }

    private func validateForSelection(_ source: TISInputSource) -> Bool {
        let sourceID = stringProperty(kTISPropertyInputSourceID, of: source) ?? "未知"

        guard boolProperty(kTISPropertyInputSourceIsSelectCapable, of: source) == true else {
            logger.error("输入源不可选择：\(sourceID, privacy: .public)")
            return false
        }

        guard boolProperty(kTISPropertyInputSourceIsEnabled, of: source) == true else {
            logger.error("输入源已被用户停用：\(sourceID, privacy: .public)")
            return false
        }

        return true
    }

    private func parentInputSource(for source: TISInputSource) -> TISInputSource? {
        guard let bundleIdentifier = stringProperty(kTISPropertyBundleID, of: source) else {
            return nil
        }

        let filter = [kTISPropertyBundleID: bundleIdentifier as CFString] as CFDictionary
        return inputSources(matching: filter, includeAllInstalled: true).first {
            stringProperty(kTISPropertyInputSourceType, of: $0) == kTISTypeKeyboardInputMethodModeEnabled as String
        }
    }

    private func enableParentIfNeeded(_ parent: TISInputSource, childID: String) -> Bool {
        guard boolProperty(kTISPropertyInputSourceIsEnabled, of: parent) != true else {
            return true
        }

        let parentID = stringProperty(kTISPropertyInputSourceID, of: parent) ?? "未知"
        guard boolProperty(kTISPropertyInputSourceIsEnableCapable, of: parent) == true else {
            logger.error(
                "输入模式的父输入法无法启用：子项=\(childID, privacy: .public)，父项=\(parentID, privacy: .public)"
            )
            return false
        }

        let status = TISEnableInputSource(parent)
        logger.info(
            "启用输入模式的父输入法：子项=\(childID, privacy: .public)，父项=\(parentID, privacy: .public)，状态码=\(status)"
        )

        guard status == noErr else {
            logger.error("启用父输入法失败：\(parentID, privacy: .public)，状态码=\(status)")
            return false
        }

        guard boolProperty(kTISPropertyInputSourceIsEnabled, of: parent) == true else {
            logger.error("父输入法状态未生效：\(parentID, privacy: .public)")
            return false
        }

        return true
    }

    private func inputSource(withID id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID: id as CFString] as CFDictionary
        return inputSources(matching: filter, includeAllInstalled: true).first
    }

    private func inputSources(matching filter: CFDictionary, includeAllInstalled: Bool) -> [TISInputSource] {
        guard let unmanagedSources = TISCreateInputSourceList(filter, includeAllInstalled) else {
            return []
        }

        let sources = unmanagedSources.takeRetainedValue() as NSArray
        var inputSources: [TISInputSource] = []
        for case let source as TISInputSource in sources {
            inputSources.append(source)
        }
        return inputSources
    }

    private func descriptor(for source: TISInputSource) -> InputSourceDescriptor? {
        guard let id = stringProperty(kTISPropertyInputSourceID, of: source) else {
            return nil
        }

        let name = stringProperty(kTISPropertyLocalizedName, of: source) ?? id
        return InputSourceDescriptor(id: id, name: name)
    }

    private func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func boolProperty(_ key: CFString, of source: TISInputSource) -> Bool? {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        let value = Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }
}
