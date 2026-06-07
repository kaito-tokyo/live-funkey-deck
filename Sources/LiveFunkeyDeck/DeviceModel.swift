// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
//  Sources/LiveFunkeyDeck/DeviceModel.swift
//  LiveFunkeyDeck
//
//  Version: 1.0.0
//  Date: 2026-06-07
//

protocol DeviceModel {
    var name: String { get }
    var vendorID: Int { get }
    var productID: Int { get }
}

protocol BaseStreamDeckModel: DeviceModel {
    var columns: Int { get }
    var rows: Int { get }
}

struct StreamDeckClassicModel: BaseStreamDeckModel {
    let name: String
    let vendorID: Int = 0x0FD9
    let productID: Int
    let columns: Int
    let rows: Int
}

enum DeviceRegistry {
    static let streamDeckMk2 = StreamDeckClassicModel(
        name: "Stream Deck Mk.2",
        productID: 0x0080,
        columns: 5,
        rows: 3
    )

    static var knownModels: [any DeviceModel] {
        [
            streamDeckMk2
        ]
    }
}
