/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Sources/LiveFunkeyDeck/DeviceModel.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-08
///

struct DeviceID: Hashable {
    let vendorID: UInt16
    let productID: UInt16
}

protocol DeviceModel {
    var deviceID: DeviceID { get }
}

protocol BaseStreamDeckModel: DeviceModel {
    var columns: Int { get }
    var rows: Int { get }
    var keyCount: Int { get }
}

struct StreamDeckClassicModel: BaseStreamDeckModel {
    let deviceID: DeviceID
    let columns: Int
    let rows: Int
    let width: Int
    let height: Int

    var keyCount: Int { columns * rows }
}

extension StreamDeckClassicModel {
    static let streamDeckMk2 = StreamDeckClassicModel(
        deviceID: DeviceID(vendorID: 0x0FD9, productID: 0x0080),
        columns: 5,
        rows: 3,
        width: 72,
        height: 72
    )
}
