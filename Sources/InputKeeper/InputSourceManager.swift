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

protocol InputSourceManaging: AnyObject {
    func currentInputSource() -> InputSourceDescriptor?
    func inputSourceName(for id: String) -> String?
    func selectInputSource(withID id: String) -> Bool
}

final class SystemInputSourceManager: InputSourceManaging {
    private let logger = Logger(subsystem: "com.chinnsii.InputKeeper", category: "InputSource")

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

        let status = TISSelectInputSource(source)
        let currentID = currentInputSource()?.id ?? "未知"
        logger.info(
            "切换输入源：目标=\(id, privacy: .public)，状态码=\(status)，当前=\(currentID, privacy: .public)"
        )
        if status != noErr {
            logger.error("切换输入源失败：\(id, privacy: .public)，状态码：\(status)")
        }
        return status == noErr
    }

    private func inputSource(withID id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID: id as CFString] as CFDictionary
        guard let unmanagedSources = TISCreateInputSourceList(filter, true) else {
            return nil
        }

        let sources = unmanagedSources.takeRetainedValue() as NSArray
        for case let source as TISInputSource in sources {
            return source
        }
        return nil
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
}
