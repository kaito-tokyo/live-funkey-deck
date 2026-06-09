/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Sources/LiveFunkeyDeck/DeviceModelHIDExtensions.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-08
///

import Foundation
import IOKit.hid

enum BaseStreamDeckModelError: Error {
    case invalidReportLength(length: CFIndex)
    case invalidReport(reportID: UInt8, command: UInt8? = nil)
    case invalidUnitSerialNumberDataLength(UInt8)
    case iokitError(IOReturn)
}

extension BaseStreamDeckModelError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidReportLength(let length):
            "Report length is invalid: \(length)."
        case .invalidReport(let reportID, let command):
            if let command {
                "Invalid report: \(reportID) \(command)."
            } else {
                "Invalid report: \(reportID)."
            }
        case .invalidUnitSerialNumberDataLength(let dataLength):
            "Invalid data length of get unit serial number: \(dataLength)."
        case .iokitError(let result):
            "IOKit error: \(result)."
        }
    }
}

extension BaseStreamDeckModel {
    func parsePressStateChangeReport(report: UnsafePointer<UInt8>, reportLength: CFIndex)
        throws(BaseStreamDeckModelError) -> Set<Int>
    {
        guard reportLength >= 4 + keyCount else {
            throw BaseStreamDeckModelError.invalidReportLength(length: reportLength)
        }

        guard report[0] == 0x01 && report[1] == 0x00 else {
            throw BaseStreamDeckModelError.invalidReport(reportID: report[0], command: report[1])
        }

        var pressState = Set<Int>()
        for keyIndex in 0..<keyCount {
            if report[4 + keyIndex] == 0x01 {
                pressState.insert(keyIndex)
            }
        }
        return pressState
    }

    func getUnitSerialNumber(device: IOHIDDevice) throws(BaseStreamDeckModelError) -> String {
        var reportSize = CFIndex(32)
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        defer { report.deallocate() }
        report.initialize(repeating: 0, count: reportSize)
        report[0] = 0x06  // Get Unit Serial Number

        let result = IOHIDDeviceGetReport(
            device,
            kIOHIDReportTypeFeature,
            0x06,
            report,
            &reportSize
        )

        guard result == kIOReturnSuccess else { throw .iokitError(result) }
        guard reportSize == 32 else { throw .invalidReportLength(length: reportSize) }
        guard report[0] == 0x06 else { throw .invalidReport(reportID: report[0]) }
        guard report[1] == 0x0C || report[1] == 0x0E else {
            throw .invalidUnitSerialNumberDataLength(report[1])
        }

        let serialNumber = String(
            decoding: UnsafeBufferPointer(start: report.advanced(by: 2), count: Int(report[1])),
            as: UTF8.self
        )

        return serialNumber
    }

    func showLogo(device: IOHIDDevice) -> IOReturn {
        let reportSize = 32
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        defer { report.deallocate() }
        report.initialize(repeating: 0, count: reportSize)
        report[0] = 0x03  // Setter Feature
        report[1] = 0x02  // Show Logo

        return IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x03, report, reportSize)
    }
}

extension DeviceModel {
    func getDeviceDescription(_ device: IOHIDDevice) -> String {
        guard
            let deviceProduct = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString)
                as? String
        else {
            return ""
        }

        switch self {
        case let deviceModel as BaseStreamDeckModel:
            let unitSerialNumber = try? deviceModel.getUnitSerialNumber(device: device)
            let serialNumber = unitSerialNumber ?? "(unknown)"
            return "product=\(deviceProduct)\tserialNumber=\(serialNumber)"
        default:
            return "product=\(deviceProduct)"
        }
    }
}
