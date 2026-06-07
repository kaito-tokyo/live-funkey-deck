// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
//  Sources/LiveFunkeyDeck/main.swift
//  LiveFunkeyDeck
//
//  Version: 1.0.0
//  Date: 2026-06-06
//

import ApplicationServices
import Foundation
import IOKit.hid
import ImageIO
import UniformTypeIdentifiers
import os

private let kVersion = "0.1.0"
private let kUsage = """
    live-funkey-deck: Small function key provider for Stream Deck
    Usage: live-funkey-deck
      --shortcut-folder=NAME  Shortcut folder name to use. Default to live-funkey-deck.
      --serial-number=STRING  Serial number to select device. Optional when single device connected.
    """

private let kDataDir = URL.applicationSupportDirectory.appending(
    path: "tokyo.kaito.live-funkey-deck",
    directoryHint: .isDirectory
)
private let kExtractIconShortcutName = "tokyo.kaito.live-funkey-deck.extract-icons"

func writeError(_ string: String) {
    let handled: Void? = string.utf8.withContiguousStorageIfAvailable { buffer in
        _ = try? FileHandle.standardError.write(contentsOf: UnsafeRawBufferPointer(buffer))
    }
    if handled == nil, let data = string.data(using: .utf8) {
        try? FileHandle.standardError.write(contentsOf: data)
    }
}

private func parseArgs(_ args: ArraySlice<String>) -> (
    opts: [String: String], flags: Set<String>, posArgs: [String]
) {
    var opts: [String: String] = [:]
    var flags = Set<String>()
    var posArgs: [String] = []
    var tail = args

    while let arg = tail.popFirst() {
        if arg == "--" {
            posArgs.append(contentsOf: tail)
            break
        } else if let match = arg.wholeMatch(of: /(--[^=]+)=(.*)/) {
            opts[String(match.output.1)] = String(match.output.2)
        } else if arg.hasPrefix("--") {
            if tail.first?.hasPrefix("--") == false {
                opts[arg] = tail.popFirst()
            } else {
                flags.insert(arg)
            }
        } else {
            posArgs.append(arg)
        }
    }

    return (opts, flags, posArgs)
}

var (opts, flags, posArgs) = parseArgs(CommandLine.arguments.dropFirst())

if flags.remove("--help") != nil {
    print(kUsage)
    exit(EX_OK)
} else if flags.remove("--version") != nil {
    print("live-funkey-deck \(kVersion)")
    exit(EX_OK)
} else if flags.remove("--licenses") != nil {
    print("## Font license")
    print(PackageResources.font_license_txt)
    exit(EX_OK)
}

let shortcutFolder = opts.removeValue(forKey: "--shortcut-folder") ?? "live-funkey-deck"
let serialNumber = opts.removeValue(forKey: "--serial-number")

guard opts.isEmpty && flags.isEmpty && posArgs.isEmpty else {
    writeError("ERROR: Unrecognized option(s) found.\n\(kUsage)\n")
    exit(EX_USAGE)
}

let manager = IOHIDManagerCreate(nil, 0)
IOHIDManagerSetDeviceMatchingMultiple(
    manager,
    DeviceRegistry.knownModels.map { $0.devicePredicate } as CFArray
)
IOHIDManagerOpen(manager, 0)
defer { IOHIDManagerClose(manager, 0) }

guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
    writeError("ERROR: No device found. Exiting...\n")
    exit(EX_USAGE)
}

let detectedDevices = deviceSet.compactMap { device -> (IOHIDDevice, any DeviceModel)? in
    guard let deviceModel = DeviceRegistry.knownModels.first(where: { $0.matches(device: device) })
    else {
        return nil
    }

    return (device, deviceModel)
}

func printDetectedDevices(detectedDevices: [(IOHIDDevice, any DeviceModel)]) {
    for (device, deviceModel) in detectedDevices {
        switch deviceModel {
        case let deviceModel as BaseStreamDeckModel:
            if let deviceSerialNumber = deviceModel.getUnitSerialNumber(device: device) {
                print("- \(deviceModel.name): \(deviceSerialNumber)")
            } else {
                print("- \(deviceModel.name): no serial number")
            }
        default: print("- unknown device: no serial number")
        }
    }
}

let device: IOHIDDevice
let deviceModel: any DeviceModel
if detectedDevices.count == 0 {
    writeError("ERROR: No device detected. Exiting...\n")
    exit(EX_USAGE)
} else if let serialNumber {
    let detected = detectedDevices.first { (device, deviceModel) in
        deviceModel.getSerialNumber(device: device) == serialNumber
    }

    guard let (detectedDevice, detectedDeviceModel) = detected else {
        writeError("ERROR: No device matched with provided serial number. Exiting\n\(kUsage)\n")
        printDetectedDevices(detectedDevices: detectedDevices)
        exit(EX_CONFIG)
    }

    device = detectedDevice
    deviceModel = detectedDeviceModel
} else if detectedDevices.count == 1,
    let (detectedDevice, detectedDeviceModel) = detectedDevices.first
{
    device = detectedDevice
    deviceModel = detectedDeviceModel
} else {
    writeError("ERROR: Multiple devices detected. Specify one with --serial-number.\n\(kUsage)\n")
    printDetectedDevices(detectedDevices: detectedDevices)
    exit(EX_USAGE)
}

extension UnsafeMutableBufferPointer where Element == UInt8 {
    func storeLE(uint16: UInt16, at index: Self.Index) {
        Swift.withUnsafeBytes(of: uint16.littleEndian) { bytes in
            self[index] = bytes[0]
            self[index + 1] = bytes[1]
        }
    }
}

func streamDeckClassicKeyImageBytes(from url: URL) -> [UInt8]? {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        return nil
    }

    let bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
    guard
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil,
            width: Int(bounds.width),
            height: Int(bounds.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else {
        return nil
    }

    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(bounds)
    context.translateBy(x: bounds.width, y: bounds.height)
    context.rotate(by: .pi)
    context.draw(image, in: bounds)

    guard let rotatedImage = context.makeImage() else {
        return nil
    }

    let data = NSMutableData()
    guard
        let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )
    else {
        return nil
    }

    CGImageDestinationAddImage(
        destination,
        rotatedImage,
        [
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImagePropertyJFIFIsProgressive: false,
        ] as CFDictionary
    )

    guard CGImageDestinationFinalize(destination) else {
        return nil
    }

    return [UInt8](data as Data)
}

class BaseDeviceHandler {
    func onReport(
        _ result: IOReturn,
        _ sender: IOHIDDevice,
        _ type: IOHIDReportType,
        _ reportID: UInt32,
        _ report: UnsafeBufferPointer<UInt8>
    ) {
    }
}

class StreamDeckHandler: BaseDeviceHandler {
    let deviceModel: BaseStreamDeckModel
    let keyShortcuts: [ShortcutRunner]

    var previousPressState: [Bool]

    init(deviceModel: BaseStreamDeckModel, keyShortcuts: [ShortcutRunner]) {
        previousPressState = [Bool](repeating: false, count: deviceModel.columns * deviceModel.rows)
        self.deviceModel = deviceModel
        self.keyShortcuts = keyShortcuts
    }

    func setupKeyShortcuts() {
    }

    func uploadKeyImages(device: IOHIDDevice) {
    }

    func onPressStateChanged(index: Int, isDown: Bool) {
    }

    override func onReport(
        _ result: IOReturn,
        _ sender: IOHIDDevice,
        _ type: IOHIDReportType,
        _ reportID: UInt32,
        _ report: UnsafeBufferPointer<UInt8>
    ) {
        guard result == kIOReturnSuccess else { return }

        if type == kIOHIDReportTypeInput && reportID == 0x01 {
            if let pressState = deviceModel.parsePressStateChangeReport(report: report) {
                let changes = pressState.indices.filter {
                    pressState[$0] != previousPressState[$0]
                }
                previousPressState = pressState

                for index in changes {
                    onPressStateChanged(index: index, isDown: pressState[index])
                }
            }
        }
    }
}

class StreamDeckClassicHandler: StreamDeckHandler {
    let keys: [KeyCode] = [
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12, .f13, .f14, .f15,
    ]

    let keyNameMapping: [String: KeyCode] = [
        "F1": .f1,
        "F2": .f2,
        "F3": .f3,
        "F4": .f4,
        "F5": .f5,
        "F6": .f6,
        "F7": .f7,
        "F8": .f8,
        "F9": .f9,
        "F10": .f10,
        "F11": .f11,
        "F12": .f12,
        "F13": .f13,
        "F14": .f14,
        "F15": .f15,
    ]

    var keyImages: [KeyCode: [UInt8]] = [
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

    override func setupKeyShortcuts() {
        for (keyName, keyCode) in keyNameMapping {
            guard let shortcut = keyShortcuts.first(where: { $0.key == keyName }) else {
                continue
            }

            print("Key Shortcut found: \(shortcut.name)")

            let pngURL = kDataDir.appending(
                path: "ShortcutIcons/\(shortcut.name).png", directoryHint: .notDirectory)

            guard let data = streamDeckClassicKeyImageBytes(from: pngURL) else {
                writeError("WARNING: Failed to load Shortcut icon for \(shortcut.name)\n")
                continue
            }

            keyImages[keyCode] = data
        }
    }

    override func uploadKeyImages(device: IOHIDDevice) {
        let reportSize = 1024
        let report = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: reportSize)
        let maxChunkSize = 1016
        for (keyIndex, keyCode) in keys.enumerated() {
            guard let keyImageBytes = keyImages[keyCode] else {
                writeError("WARNING: Key image of \(keyIndex) is missing")
                continue
            }

            for (chunkIndex, byteOffset) in stride(
                from: 0, to: keyImageBytes.count, by: maxChunkSize
            ).enumerated() {
                let end = min(byteOffset + maxChunkSize, keyImageBytes.count)
                let chunk = keyImageBytes[byteOffset..<end]

                report.initialize(repeating: 0)

                report[0] = 0x02  // Report ID
                report[1] = 0x07  // Command
                report[2] = UInt8(keyIndex)  // Key Index
                report[3] = end == keyImageBytes.count ? 0x01 : 0x00  // Transfer is Done flag
                report.storeLE(uint16: UInt16(chunk.count), at: 4)
                report.storeLE(uint16: UInt16(chunkIndex), at: 6)
                for (offset, byte) in chunk.enumerated() {
                    report[8 + offset] = byte
                }

                guard
                    deviceModel.writeOutputReport(
                        device: device,
                        reportID: 0x02,
                        report: UnsafeBufferPointer<UInt8>(report)
                    ) == kIOReturnSuccess
                else {
                    writeError("WARNING: Updating key image of \(keyIndex) was failed")
                    continue
                }
            }
        }
    }

    override func onPressStateChanged(index: Int, isDown: Bool) {
        let functionKeyIndex = index + 1
        if isDown {
            print("F\(functionKeyIndex) down")
        } else {
            print("F\(functionKeyIndex) up")

            let shortcut = keyShortcuts.first { $0.key == "F\(functionKeyIndex)" }
            if let shortcut {
                print("Invoked \(shortcut.name)")
                shortcut.runAndForget()
            }
        }
    }
}

func hidReportCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ type: IOHIDReportType,
    _ reportID: UInt32,
    _ report: UnsafeMutablePointer<UInt8>,
    _ reportLength: CFIndex
) {
    switch type {
    case kIOHIDReportTypeCount, kIOHIDReportTypeFeature, kIOHIDReportTypeInput,
        kIOHIDReportTypeOutput:
        guard let context, let sender else { return }
        Unmanaged<BaseDeviceHandler>.fromOpaque(context).takeUnretainedValue().onReport(
            result,
            Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue(),
            type,
            reportID,
            UnsafeBufferPointer<UInt8>(start: report, count: Int(reportLength))
        )
    default: return
    }
}

guard let runLoop = CFRunLoopGetCurrent() else {
    writeError("ERROR: Failed to start program. Exiting...")
    exit(1)
}

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigintSource.setEventHandler { CFRunLoopStop(runLoop) }
sigtermSource.setEventHandler { CFRunLoopStop(runLoop) }

let extractIconShortcut = ShortcutRunner(name: kExtractIconShortcutName)
_ = extractIconShortcut.runAndWait()

let keyShortcuts = ShortcutRunner.listKeyShortcuts(in: shortcutFolder)

if let deviceModel = deviceModel as? BaseStreamDeckModel {
    let inputReportSize = 512
    let inputReport = UnsafeMutablePointer<UInt8>.allocate(capacity: inputReportSize)

    let handler =
        switch deviceModel {
        case let deviceModel as StreamDeckClassicModel:
            StreamDeckClassicHandler(deviceModel: deviceModel, keyShortcuts: keyShortcuts)
        default:
            StreamDeckHandler(deviceModel: deviceModel, keyShortcuts: keyShortcuts)
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

    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    sigintSource.activate()
    sigtermSource.activate()

    CFRunLoopRun()

    sigintSource.cancel()
    sigtermSource.cancel()

    IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)

    _ = deviceModel.showLogo(device: device)
}
