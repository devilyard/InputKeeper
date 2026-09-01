// swift-tools-version: 5.10
//
//  Package.swift
//  InputKeeper
//
//  Created by chinnsii on 2026/8/24.
//

import PackageDescription

let package = Package(
    name: "InputKeeper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "InputKeeper", targets: ["InputKeeper"])
    ],
    targets: [
        .executableTarget(
            name: "InputKeeper"
        ),
        .testTarget(
            name: "InputKeeperTests",
            dependencies: ["InputKeeper"]
        )
    ]
)
