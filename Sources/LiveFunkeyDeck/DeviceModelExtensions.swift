// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
//  Sources/LiveFunkeyDeck/DeviceModelExtensions.swift
//  LiveFunkeyDeck
//
//  Version: 1.0.0
//  Date: 2026-06-07
//

import Foundation
import IOKit.hid

extension DeviceModel {
    var devicePredicate: [String: Any] {
        [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID,
        ]
    }

    func matches(device: IOHIDDevice) -> Bool {
        guard
            let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
            let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        else {
            return false
        }

        return vid == vendorID && pid == productID
    }
}

enum ReportID: UInt32 {
    case pressStateChange = 0x01
    case getUnitSerialNumber = 0x06
}

extension BaseStreamDeckModel {
    func writeOutputReport(
        device: IOHIDDevice, reportID: CFIndex, report: UnsafeBufferPointer<UInt8>
    ) -> IOReturn {
        guard report[0] == reportID, let rawReport = report.baseAddress else {
            return kIOReturnError
        }
        return IOHIDDeviceSetReport(
            device, kIOHIDReportTypeOutput, reportID, rawReport, report.count)
    }

    func getFeatureReport(device: IOHIDDevice, reportID: UInt8, command: UInt8 = 0)
        -> UnsafeRawBufferPointer?
    {
        var reportSize: CFIndex = 32
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        report.initialize(repeating: 0, count: 32)
        report[0] = reportID
        report[1] = command

        guard
            IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                CFIndex(reportID),
                report,
                &reportSize
            ) == kIOReturnSuccess
        else {
            return nil
        }

        return UnsafeRawBufferPointer(start: report, count: reportSize)
    }

    func parsePressStateChangeReport(report: UnsafeBufferPointer<UInt8>) -> [Bool]? {
        let keyCount = columns * rows
        guard
            report.count >= 4 + keyCount,
            report[0] == ReportID.pressStateChange.rawValue,
            report[1] == 0
        else {
            return nil
        }

        return report[4..<4 + keyCount].map { $0 == 0x01 }
    }

    func getUnitSerialNumber(device: IOHIDDevice) -> String? {
        guard
            let report = getFeatureReport(device: device, reportID: 0x06),
            report[0] == ReportID.getUnitSerialNumber.rawValue
        else {
            return nil
        }

        let dataLength = Int(report[1])
        guard dataLength == 0x0C || dataLength == 0x0E else { return nil }

        return String(decoding: report[2..<2 + dataLength], as: UTF8.self)
    }
    
    func showLogo(device: IOHIDDevice) -> IOReturn {
        let reportID = 0x03 // Setter Feature
        
        let reportSize = 32
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        
        report[0] = UInt8(reportID)
        report[1] = 0x02 // Show Logo
        
        return IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, reportID, report, reportSize)
    }
}

extension StreamDeckClassicModel {
}

extension DeviceModel {
    func getSerialNumber(device: IOHIDDevice) -> String? {
        switch self {
        case let deviceModel as BaseStreamDeckModel: deviceModel.getUnitSerialNumber(device: device)
        default: nil
        }
    }
}
