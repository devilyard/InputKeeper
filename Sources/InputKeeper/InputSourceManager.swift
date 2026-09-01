//
//  InputSourceManager.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import Carbon.HIToolbox
import Foundation

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
            return false
        }
        return TISSelectInputSource(source) == noErr
    }

    private func inputSource(withID id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID: id as CFString] as CFDictionary
        guard let unmanagedSources = TISCreateInputSourceList(filter, false) else {
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
