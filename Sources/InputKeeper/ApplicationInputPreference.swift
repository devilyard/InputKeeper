//
//  ApplicationInputPreference.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import Foundation

struct ApplicationInputPreference: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    var applicationName: String
    var inputSourceID: String
    var inputSourceName: String

    var id: String {
        bundleIdentifier
    }
}
