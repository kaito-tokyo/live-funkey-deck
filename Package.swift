// swift-tools-version: 6.0

// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

import PackageDescription

let package = Package(
    name: "LiveFunkeyDeck",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "live-funkey-deck", targets: ["LiveFunkeyDeck"])
    ],
    targets: [
        .executableTarget(
            name: "LiveFunkeyDeck",
            resources: [
                .embedInCode("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
