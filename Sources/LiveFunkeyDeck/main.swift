/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Sources/LiveFunkeyDeck/main.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-08
///

import ApplicationServices
import CoreGraphics
import Foundation
import IOKit.hid
import ImageIO
import UniformTypeIdentifiers

private let kIdentifier = "tokyo.kaito.live-funkey-deck"
private let kVersion = "1.0.0"
private let kUsage = """
    live-funkey-deck \(kVersion): A small command-line utility for streamer key devices.
    Usage: live-funkey-deck [--help] [--version] [options]
      --shortcut-folder=NAME  Shortcut folder name to use. Defaults to live-funkey-deck.
      --serial-number=STRING  Serial number to select device. Optional when a single device is connected.
      --licenses              Print licenses and exit.
    """
private let kCopyright =
    "Copyright 2026 Kaito Udagawa. Licensed under the Apache License, Version 2.0."

// MARK: Argument parsing

private let shortcutFolder: String
private let serialNumber: String?
do {
    var (opts, flags, posArgs) = parseArgs(CommandLine.arguments.dropFirst())

    if flags.remove("--help") != nil {
        print(kUsage, "", kCopyright, separator: "\n")
        exit(EX_OK)
    } else if flags.remove("--version") != nil {
        print("live-funkey-deck \(kVersion)")
        exit(EX_OK)
    } else if flags.remove("--licenses") != nil {
        let license = String(decoding: PackageResources.LICENSE, as: UTF8.self)
        let notice = String(decoding: PackageResources.NOTICE, as: UTF8.self)
        let ofl = String(decoding: PackageResources.OFL_txt, as: UTF8.self)
        print(
            "<LICENSE>", license, "</LICENSE>",
            "<NOTICE>", notice, "</NOTICE>",
            "<OFL>", ofl, "</OFL>",
            separator: "\n")
        exit(EX_OK)
    }

    shortcutFolder = opts.removeValue(forKey: "--shortcut-folder") ?? "live-funkey-deck"

    guard !flags.contains("--shortcut-folder") else {
        writeError("ERROR: Missing value of --shortcut-folder.\n\(kUsage)\n")
        exit(EX_USAGE)
    }

    serialNumber = opts.removeValue(forKey: "--serial-number")

    guard !flags.contains("--serial-number") else {
        writeError("ERROR: Missing value of --serial-number.\n\(kUsage)\n")
        exit(EX_USAGE)
    }

    guard opts.isEmpty && flags.isEmpty && posArgs.isEmpty else {
        writeError("ERROR: Unrecognized option(s) found.\n\(kUsage)\n")
        exit(EX_USAGE)
    }
}

print(
    "event=argumentParsed",
    "identifier=\(kIdentifier)",
    "version=\(kVersion)",
    "shortcutFolder=\(shortcutFolder)",
    "serialNumber=\(serialNumber ?? "(not specified)")",
    separator: "\t"
)

// MARK: Device handlers

private class BaseDeviceHandler {
    func onReport(
        _ result: IOReturn,
        _ sender: IOHIDDevice,
        _ type: IOHIDReportType,
        _ reportID: UInt32,
        _ report: UnsafeMutablePointer<UInt8>,
        _ reportLength: CFIndex
    ) {
        writeError("WARNING: \(#function) is not implemented.\n")
    }
}

private func hidReportCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ type: IOHIDReportType,
    _ reportID: UInt32,
    _ report: UnsafeMutablePointer<UInt8>,
    _ reportLength: CFIndex
) {
    switch type {
    case kIOHIDReportTypeFeature, kIOHIDReportTypeInput, kIOHIDReportTypeOutput:
        guard let context, let sender else { return }
        Unmanaged<BaseDeviceHandler>.fromOpaque(context).takeUnretainedValue().onReport(
            result,
            Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue(),
            type,
            reportID,
            report,
            reportLength
        )
    default: return
    }
}

extension UnsafeMutablePointer where Pointee == UInt8 {
    fileprivate func storeLE(uint16: UInt16, at index: Self.Distance) {
        self[index] = UInt8(truncatingIfNeeded: uint16)
        self[index + 1] = UInt8(truncatingIfNeeded: uint16 >> 8)
    }
}

private class StreamDeckHandler: BaseDeviceHandler {
    let baseDeviceModel: BaseStreamDeckModel
    let functionKeyShortcuts: [FunctionKeyCode: Shortcut]

    var previousPressState = Set<Int>()

    init(baseDeviceModel: BaseStreamDeckModel, functionKeyShortcuts: [FunctionKeyCode: Shortcut]) {
        self.baseDeviceModel = baseDeviceModel
        self.functionKeyShortcuts = functionKeyShortcuts
    }

    func setupKeyShortcuts() {
        writeError("WARNING: \(#function) is not implemented.\n")
    }

    func uploadKeyImages(device: IOHIDDevice) {
        writeError("WARNING: \(#function) is not implemented.\n")
    }

    func onPressStateChanged(keyIndex: Int, isDown: Bool) {
        guard FunctionKeyCode.allCases.indices.contains(keyIndex) else {
            writeError(
                "WARNING: keyIndex \(keyIndex) is out of range (0..<\(FunctionKeyCode.allCases.count)).\n"
            )
            return
        }

        let keyCode = FunctionKeyCode.allCases[keyIndex]

        if isDown {
            print("event=keyDown\tkeyName=\(keyCode.name)")
        } else {
            print("event=keyUp\tkeyName=\(keyCode.name)")

            if let shortcut = functionKeyShortcuts[keyCode] {
                let process = Process()
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.standardError
                shortcut.runAndForget(process: process)
            }
        }
    }

    override func onReport(
        _ result: IOReturn,
        _ sender: IOHIDDevice,
        _ type: IOHIDReportType,
        _ reportID: UInt32,
        _ report: UnsafeMutablePointer<UInt8>,
        _ reportLength: CFIndex
    ) {
        guard result == kIOReturnSuccess else { return }

        if type == kIOHIDReportTypeInput && reportID == 0x01 {
            do {
                let pressState = try baseDeviceModel.parsePressStateChangeReport(
                    report: report, reportLength: reportLength)

                for keyIndex in previousPressState.subtracting(pressState) {
                    onPressStateChanged(keyIndex: keyIndex, isDown: false)
                }

                for keyIndex in pressState.subtracting(previousPressState) {
                    onPressStateChanged(keyIndex: keyIndex, isDown: true)
                }

                previousPressState = pressState
            } catch {
                writeError("ERROR: \(error.localizedDescription)\n")
            }
        }
    }
}

private class StreamDeckClassicHandler: StreamDeckHandler {
    let deviceModel: StreamDeckClassicModel
    let shortcutIconsDir: URL?

    var keyImages: [FunctionKeyCode: [UInt8]] = [
        .f1: PackageResources.f1_rot180_jpg,
        .f2: PackageResources.f2_rot180_jpg,
        .f3: PackageResources.f3_rot180_jpg,
        .f4: PackageResources.f4_rot180_jpg,
        .f5: PackageResources.f5_rot180_jpg,
        .f6: PackageResources.f6_rot180_jpg,
        .f7: PackageResources.f7_rot180_jpg,
        .f8: PackageResources.f8_rot180_jpg,
        .f9: PackageResources.f9_rot180_jpg,
        .f10: PackageResources.f10_rot180_jpg,
        .f11: PackageResources.f11_rot180_jpg,
        .f12: PackageResources.f12_rot180_jpg,
        .f13: PackageResources.f13_rot180_jpg,
        .f14: PackageResources.f14_rot180_jpg,
        .f15: PackageResources.f15_rot180_jpg,
    ]

    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    init(
        deviceModel: StreamDeckClassicModel, functionKeyShortcuts: [FunctionKeyCode: Shortcut],
        shortcutIconsDir: URL?
    ) {
        self.deviceModel = deviceModel
        self.shortcutIconsDir = shortcutIconsDir
        super.init(baseDeviceModel: deviceModel, functionKeyShortcuts: functionKeyShortcuts)
    }

    override func setupKeyShortcuts() {
        guard let shortcutIconsDir else {
            writeError("WARNING: Shortcut icons directory not set.\n")
            return
        }

        let width = deviceModel.width
        let height = deviceModel.height
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))

        guard
            let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else {
            writeError("WARNING: Failed to create CGContext.\n")
            return
        }

        for keyCode in FunctionKeyCode.allCases.prefix(deviceModel.keyCount) {
            guard let shortcut = functionKeyShortcuts[keyCode] else {
                continue
            }

            let sanitizedShortcutName = shortcut.name.replacingOccurrences(of: "/", with: ":")

            let iconURL = shortcutIconsDir.appending(
                path: "\(sanitizedShortcutName).png", directoryHint: .notDirectory)

            guard let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
                let iconImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                writeError("WARNING: Failed to load shortcut icon for \(shortcut.name).\n")
                continue
            }

            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(rect)
            context.saveGState()
            context.translateBy(x: CGFloat(deviceModel.width), y: CGFloat(deviceModel.height))
            context.rotate(by: .pi)
            context.draw(iconImage, in: rect)
            context.restoreGState()

            guard let rotatedImage = context.makeImage() else {
                writeError("WARNING: Failed to create rotated image for \(shortcut.name).\n")
                continue
            }

            let data = NSMutableData()

            guard
                let destination = CGImageDestinationCreateWithData(
                    data, UTType.jpeg.identifier as CFString, 1, nil)
            else {
                writeError("WARNING: Failed to create image destination for \(shortcut.name).\n")
                continue
            }

            CGImageDestinationAddImage(
                destination, rotatedImage,
                [
                    kCGImageDestinationLossyCompressionQuality: 0.8
                ] as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                writeError("WARNING: Failed to finalize image destination for \(shortcut.name).\n")
                continue
            }

            keyImages[keyCode] = [UInt8](data as Data)
        }
    }

    override func uploadKeyImages(device: IOHIDDevice) {
        let maxChunkSize = 1016
        let reportSize = 1024
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        report.initialize(repeating: 0, count: reportSize)
        defer { report.deallocate() }

        let keyCodes = FunctionKeyCode.allCases.prefix(deviceModel.keyCount)
        for (keyIndex, keyCode) in keyCodes.enumerated() {
            guard let keyImageBytes = keyImages[keyCode] else {
                writeError("WARNING: Key image of \(keyIndex) is missing.\n")
                continue
            }

            for (chunkIndex, byteOffset) in stride(
                from: 0, to: keyImageBytes.count, by: maxChunkSize
            ).enumerated() {
                let end = min(byteOffset + maxChunkSize, keyImageBytes.count)
                let chunk = keyImageBytes[byteOffset..<end]

                report.update(repeating: 0, count: reportSize)
                report[0] = 0x02  // Output Report
                report[1] = 0x07  // Update Key Image
                report[2] = UInt8(keyIndex)  // Key Index
                report[3] = end == keyImageBytes.count ? 0x01 : 0x00  // Transfer is Done flag

                report.storeLE(uint16: UInt16(chunk.count), at: 4)  // Chunk Contents Size
                report.storeLE(uint16: UInt16(chunkIndex), at: 6)  // Chunk Index

                for (offset, byte) in chunk.enumerated() {
                    report[8 + offset] = byte
                }

                guard
                    IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x02, report, reportSize)
                        == kIOReturnSuccess
                else {
                    writeError("WARNING: Failed to update key image of \(keyIndex).\n")
                    break
                }
            }
        }
    }
}

// MARK: Device detection

private let supportedDeviceModels: [DeviceID: any DeviceModel] = [
    StreamDeckClassicModel.streamDeckMk2.deviceID: StreamDeckClassicModel.streamDeckMk2
]

private let manager = IOHIDManagerCreate(nil, 0)
IOHIDManagerSetDeviceMatchingMultiple(
    manager,
    supportedDeviceModels.values.map {
        [
            kIOHIDVendorIDKey as String: Int($0.deviceID.vendorID),
            kIOHIDProductIDKey as String: Int($0.deviceID.productID),
        ]
    } as CFArray
)
IOHIDManagerOpen(manager, 0)
defer { IOHIDManagerClose(manager, 0) }

private let device: IOHIDDevice
private let deviceModel: any DeviceModel
do {
    guard
        let matchedDevices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
        !matchedDevices.isEmpty
    else {
        writeError("ERROR: No device found. Exiting...\n")
        exit(EX_UNAVAILABLE)
    }

    var matched: (device: IOHIDDevice, deviceModel: any DeviceModel)?
    for d in matchedDevices {
        guard
            let vendorID = IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? Int,
            let productID = IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? Int
        else {
            writeError("WARNING: Failed to get device ID. Skipping this device...\n")
            continue
        }

        let deviceID = DeviceID(
            vendorID: UInt16(truncatingIfNeeded: vendorID),
            productID: UInt16(truncatingIfNeeded: productID))

        guard let matchedDeviceModel = supportedDeviceModels[deviceID] else {
            writeError(
                "WARNING: Unsupported device vendorID=\(vendorID) productID=\(productID). Skipping this device...\n"
            )
            continue
        }

        print("event=deviceDetected\t\(matchedDeviceModel.getDeviceDescription(d))")

        if let serialNumber {
            if let streamDeckModel = matchedDeviceModel as? BaseStreamDeckModel,
                (try? streamDeckModel.getUnitSerialNumber(device: d)) == serialNumber
            {
                matched = (d, matchedDeviceModel)
                break
            }
        } else if matchedDevices.count == 1 {
            matched = (d, matchedDeviceModel)
            break
        }
    }

    guard let matched else {
        if serialNumber != nil {
            writeError("ERROR: No device has the specified serial number. Exiting...\n")
        } else {
            writeError(
                "ERROR: Multiple devices detected. Specify --serial-number to select device. Exiting...\n"
            )
        }
        exit(EX_CONFIG)
    }

    device = matched.device
    deviceModel = matched.deviceModel
}

print("event=deviceSelected\t\(deviceModel.getDeviceDescription(device))")

// MARK: Prepare shortcuts

private let shortcutFolderIdentifier: String?
do {
    shortcutFolderIdentifier = try Shortcut.listFolders(standardError: FileHandle.standardError)[
        shortcutFolder]
} catch {
    writeError("WARNING: Failed to run shortcuts command. \(error.localizedDescription)\n")
    shortcutFolderIdentifier = nil
}

private let shortcuts: [String: Shortcut]
private let shortcutIconsDir: URL?
if let shortcutFolderIdentifier {
    do {
        shortcuts = try Shortcut.listShortcuts(
            in: shortcutFolder, standardError: FileHandle.standardError)
    } catch {
        writeError("WARNING: Failed to run shortcuts command. \(error.localizedDescription)\n")
        shortcuts = [:]
    }

    shortcutIconsDir = URL.applicationSupportDirectory.appendingPathComponent(
        "\(kIdentifier)/ShortcutIcons/\(shortcutFolderIdentifier)", isDirectory: true)
} else {
    writeError("WARNING: Shortcut folder \(shortcutFolder) not found, or could not be listed.\n")
    shortcuts = [:]
    shortcutIconsDir = nil
}

private let extractIconShortcut = shortcuts["tokyo.kaito.live-funkey-deck.extract-icons"]

if let shortcutIconsDir, let extractIconShortcut {
    print("event=extractIconsInvoked")
    do {
        try FileManager.default.createDirectory(
            at: shortcutIconsDir, withIntermediateDirectories: true)

        let process = Process()
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError

        // Passing not-path shortcutFolder as inputPath INTENTIONALLY
        try extractIconShortcut.runAndWait(
            process: process,
            inputPath: shortcutFolder,
            outputPath: shortcutIconsDir.path(percentEncoded: false)
        )
    } catch {
        writeError("WARNING: Failed to extract shortcut icons. \(error.localizedDescription)\n")
    }
} else {
    writeError("INFO: Failed to extract shortcut icons.\n")
    if shortcutIconsDir == nil {
        writeError("DEBUG: shortcutIconsDir is nil.\n")
    }
    if extractIconShortcut == nil {
        writeError("DEBUG: extractIconShortcut is nil.\n")
    }
}

private let functionKeyShortcuts: [FunctionKeyCode: Shortcut]
if shortcuts.isEmpty {
    functionKeyShortcuts = [:]
} else {
    var dict: [FunctionKeyCode: Shortcut] = [:]
    for (shortcutName, shortcut) in shortcuts {
        guard
            let m = shortcutName.prefixMatch(of: /F([0-9]+)\ /),
            let functionNumber = Int(m.output.1)
        else { continue }

        guard FunctionKeyCode.allCases.count >= functionNumber && functionNumber > 0 else {
            continue
        }
        let keyCode = FunctionKeyCode.allCases[functionNumber - 1]

        guard dict[keyCode] == nil else {
            writeError(
                "ERROR: Multiple shortcuts are found for the function key \(functionNumber). Exiting...\n"
            )
            exit(EX_CONFIG)
        }

        dict[keyCode] = shortcut
    }

    functionKeyShortcuts = dict
}

// MARK: Main program

private let runLoop = CFRunLoopGetCurrent()

guard let runLoop else {
    writeError("ERROR: Failed to get run loop. Exiting...\n")
    exit(EX_SOFTWARE)
}

private let exitSignals = [SIGHUP, SIGINT, SIGTERM]

for exitSignal in exitSignals {
    signal(exitSignal, SIG_IGN)
}

private let exitSources = exitSignals.map {
    DispatchSource.makeSignalSource(signal: $0, queue: .main)
}
for exitSource in exitSources {
    exitSource.setEventHandler {
        CFRunLoopStop(runLoop)
    }
}

if let deviceModel = deviceModel as? BaseStreamDeckModel {
    let inputReportSize = 512
    let inputReport = UnsafeMutablePointer<UInt8>.allocate(capacity: inputReportSize)
    defer { inputReport.deallocate() }

    let handler: StreamDeckHandler
    switch deviceModel {
    case let deviceModel as StreamDeckClassicModel:
        handler = StreamDeckClassicHandler(
            deviceModel: deviceModel, functionKeyShortcuts: functionKeyShortcuts,
            shortcutIconsDir: shortcutIconsDir)
    default:
        handler = StreamDeckHandler(
            baseDeviceModel: deviceModel, functionKeyShortcuts: functionKeyShortcuts)
    }

    handler.setupKeyShortcuts()
    handler.uploadKeyImages(device: device)

    IOHIDDeviceRegisterInputReportCallback(
        device,
        inputReport,
        inputReportSize,
        hidReportCallback,
        Unmanaged.passUnretained(handler).toOpaque()
    )

    IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)

    for exitSource in exitSources {
        exitSource.activate()
    }

    CFRunLoopRun()

    for exitSource in exitSources {
        exitSource.cancel()
    }

    IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)

    if deviceModel.showLogo(device: device) == kIOReturnSuccess {
        print("event=resetDevice")
    } else {
        writeError("WARNING: Failed to reset the device.\n")
    }
}
