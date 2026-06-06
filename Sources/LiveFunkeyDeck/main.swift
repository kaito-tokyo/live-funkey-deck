import ApplicationServices
import Dispatch
import Foundation
import ImageIO
import IOKit.hid
import UniformTypeIdentifiers

let elgatoVendorID = 0x0FD9
let keyCount = 15
let shortcutFolderName = "Live Funkey Deck"
let iconExtractorShortcutName = "tokyo.kaito.live-funkey-deck.extract-icons"
let shortcutIconsDirectory = "Library/Application Support/tokyo.kaito.live-funkey-deck/ShortcutIcons"

struct StreamDeckModel: Sendable {
    let name: String
    let productID: Int
    let columns = 5
    let rows = 3

    var keyCount: Int { columns * rows }
}

let supportedModels = [
    StreamDeckModel(name: "Stream Deck Mk.2", productID: 0x0080)
]

enum LiveFunkeyDeckError: Error, CustomStringConvertible {
    case noSupportedDevice
    case openFailed(Int32)
    case reportFailed(operation: String, Int32)
    case invalidArgument(String)
    case imageLoadFailed(String)

    var description: String {
        switch self {
        case .noSupportedDevice:
            "No supported Stream Deck device was found. Quit the official Stream Deck app if it has the device open."
        case let .openFailed(code):
            "Failed to open HID device: IOReturn \(code)"
        case let .reportFailed(operation, code):
            "\(operation) failed: IOReturn \(code)"
        case let .invalidArgument(message):
            message
        case let .imageLoadFailed(label):
            "Could not load image for \(label)"
        }
    }
}

struct FunctionKey: Sendable {
    let label: String
    let keyCode: CGKeyCode
}

let functionKeys: [FunctionKey] = [
    FunctionKey(label: "F1", keyCode: 122),
    FunctionKey(label: "F2", keyCode: 120),
    FunctionKey(label: "F3", keyCode: 99),
    FunctionKey(label: "F4", keyCode: 118),
    FunctionKey(label: "F5", keyCode: 96),
    FunctionKey(label: "F6", keyCode: 97),
    FunctionKey(label: "F7", keyCode: 98),
    FunctionKey(label: "F8", keyCode: 100),
    FunctionKey(label: "F9", keyCode: 101),
    FunctionKey(label: "F10", keyCode: 109),
    FunctionKey(label: "F11", keyCode: 103),
    FunctionKey(label: "F12", keyCode: 111),
    FunctionKey(label: "F13", keyCode: 105),
    FunctionKey(label: "F14", keyCode: 107),
    FunctionKey(label: "F15", keyCode: 113)
]

do {
    try run(Array(CommandLine.arguments.dropFirst()))
} catch {
    fputs("LiveFunkeyDeck: \(error)\n", stderr)
    Foundation.exit(1)
}

func run(_ arguments: [String]) throws {
    if arguments == ["--help"] || arguments == ["-h"] {
        printUsage()
        return
    }
    if arguments == ["--license"] || arguments == ["--licenses"] {
        print(String(decoding: PackageResources.font_license_txt, as: UTF8.self))
        return
    }

    guard arguments.isEmpty else {
        throw LiveFunkeyDeckError.invalidArgument("Usage: LiveFunkeyDeck")
    }

    let device = try StreamDeckDevice.first()
    try device.open()
    defer { device.close() }

    try runFunctionKeyMode(device: device)
}

func printUsage() {
    print("""
    Usage:
      LiveFunkeyDeck

    Paints a 15-button Stream Deck as F1-F15 and maps button presses to Shortcuts or macOS function-key events.
    Press Control-C to stop.
    Use --license to print bundled asset license information.
    """)
}

func runFunctionKeyMode(device: StreamDeckDevice) throws {
    guard device.model.keyCount == functionKeys.count else {
        throw LiveFunkeyDeckError.invalidArgument("This command requires a 15-button Stream Deck.")
    }

    let shortcutRunner = ShortcutRunner()
    let shortcutsByKeyLabel = shortcutRunner.availableShortcutsByKeyLabel()
    let actions = functionKeys.map { functionKey -> FunctionKeyAction in
        if let shortcut = shortcutsByKeyLabel[functionKey.label] {
            return .shortcut(keyLabel: functionKey.label, identifier: shortcut.identifier)
        }
        return .keyboard(keyCode: functionKey.keyCode)
    }

    for (index, functionKey) in functionKeys.enumerated() {
        let shortcutImageData = shortcutsByKeyLabel[functionKey.label]?.iconJPEGData
        try device.setKeyImage(index: index, jpegData: shortcutImageData ?? fKeyJPEGData(label: functionKey.label))
    }

    let keyboardActionCount = actions.filter(\.usesKeyboard).count
    let shortcutActionCount = actions.count - keyboardActionCount
    print("Enabled \(shortcutActionCount) Shortcuts and \(keyboardActionCount) function-key fallbacks.")

    let synthesizer = KeyboardSynthesizer()
    if keyboardActionCount > 0 && !synthesizer.isTrustedForAccessibility {
        print("Accessibility permission may be required before macOS accepts fallback function-key events.")
    }

    let state = FunctionKeyModeState(actions: actions, shortcutRunner: shortcutRunner, synthesizer: synthesizer)
    installSignalHandlers()
    print("LiveFunkeyDeck is running. Press Control-C to stop.")
    device.listen { states in
        state.handle(states)
    }
    CFRunLoopRun()
    state.releaseAll()
    showLogo(device: device)
}

func fKeyJPEGData(label: String) throws -> Data {
    guard label.first == "F", let index = Int(label.dropFirst()) else {
        throw LiveFunkeyDeckError.imageLoadFailed(label)
    }
    return try Data(fKeyJPEGBytes(index: index))
}

func fKeyJPEGBytes(index: Int) throws -> [UInt8] {
    switch index {
    case 1: PackageResources.f1_jpg
    case 2: PackageResources.f2_jpg
    case 3: PackageResources.f3_jpg
    case 4: PackageResources.f4_jpg
    case 5: PackageResources.f5_jpg
    case 6: PackageResources.f6_jpg
    case 7: PackageResources.f7_jpg
    case 8: PackageResources.f8_jpg
    case 9: PackageResources.f9_jpg
    case 10: PackageResources.f10_jpg
    case 11: PackageResources.f11_jpg
    case 12: PackageResources.f12_jpg
    case 13: PackageResources.f13_jpg
    case 14: PackageResources.f14_jpg
    case 15: PackageResources.f15_jpg
    default: throw LiveFunkeyDeckError.imageLoadFailed("F\(index)")
    }
}

func showLogo(device: StreamDeckDevice) {
    do {
        try device.showLogo()
    } catch {
        fputs("Could not show Stream Deck logo: \(error)\n", stderr)
    }
}

func installSignalHandlers() {
    signal(SIGINT) { _ in CFRunLoopStop(CFRunLoopGetMain()) }
    signal(SIGTERM) { _ in CFRunLoopStop(CFRunLoopGetMain()) }
}

final class StreamDeckDevice {
    let model: StreamDeckModel
    private let device: IOHIDDevice

    init(device: IOHIDDevice, model: StreamDeckModel) {
        self.device = device
        self.model = model
    }

    static func first() throws -> StreamDeckDevice {
        guard let device = all().first else {
            throw LiveFunkeyDeckError.noSupportedDevice
        }
        return device
    }

    static func all() -> [StreamDeckDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches = supportedModels.map { model -> [String: Any] in
            [
                kIOHIDVendorIDKey as String: elgatoVendorID,
                kIOHIDProductIDKey as String: model.productID
            ]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        return deviceSet.compactMap { device in
            guard
                let productID = intProperty(device, kIOHIDProductIDKey as String),
                let model = supportedModels.first(where: { $0.productID == productID })
            else {
                return nil
            }
            return StreamDeckDevice(device: device, model: model)
        }
        .sorted { $0.model.productID < $1.model.productID }
    }

    func open() throws {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw LiveFunkeyDeckError.openFailed(result)
        }
    }

    func close() {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func setKeyImage(index: Int, jpegData: Data) throws {
        guard (0..<model.keyCount).contains(index) else {
            throw LiveFunkeyDeckError.invalidArgument("Key index must be between 0 and \(model.keyCount - 1).")
        }
        try sendChunkedImage(command: 0x07, target: UInt8(index), jpegData: jpegData)
    }

    func showLogo() throws {
        try sendFeatureReport(command: 0x02)
    }

    func listen(handler: @escaping @Sendable ([Bool]) -> Void) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
        buffer.initialize(repeating: 0, count: 512)

        let context = InputCallbackContext(keyCount: model.keyCount, handler: handler, buffer: buffer)
        let opaqueContext = Unmanaged.passRetained(context).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(device, buffer, 512, { context, _, _, _, _, report, reportLength in
            guard let context else { return }
            let callbackContext = Unmanaged<InputCallbackContext>.fromOpaque(context).takeUnretainedValue()
            guard reportLength >= 4, report[0] == 0x01, report[1] == 0x00 else { return }
            let payloadLength = min(Int(report[2]) | (Int(report[3]) << 8), reportLength - 4)
            let states = (0..<min(payloadLength, callbackContext.keyCount)).map { report[4 + $0] != 0 }
            callbackContext.handler(states)
        }, opaqueContext)

        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func sendChunkedImage(command: UInt8, target: UInt8, jpegData: Data) throws {
        let maxReportSize = 1024
        let headerSize = 8
        let chunkSize = maxReportSize - headerSize
        let totalChunks = max(1, Int(ceil(Double(jpegData.count) / Double(chunkSize))))

        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, jpegData.count)
            let chunk = jpegData[start..<end]
            var report = [UInt8](repeating: 0, count: maxReportSize)

            report[0] = 0x02
            report[1] = command
            report[2] = target
            report[3] = chunkIndex == totalChunks - 1 ? 0x01 : 0x00
            writeUInt16LE(UInt16(chunk.count), into: &report, at: 4)
            writeUInt16LE(UInt16(chunkIndex), into: &report, at: 6)
            report.replaceSubrange(headerSize..<(headerSize + chunk.count), with: chunk)
            let reportCount = report.count

            let result = report.withUnsafeMutableBytes { rawBuffer in
                IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeOutput,
                    0x02,
                    rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    reportCount
                )
            }
            guard result == kIOReturnSuccess else {
                throw LiveFunkeyDeckError.reportFailed(operation: "Send image chunk \(chunkIndex)", result)
            }
        }
    }

    private func sendFeatureReport(command: UInt8) throws {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x03
        report[1] = command
        let reportCount = report.count

        let result = report.withUnsafeMutableBytes { rawBuffer in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeFeature,
                0x03,
                rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                reportCount
            )
        }
        guard result == kIOReturnSuccess else {
            throw LiveFunkeyDeckError.reportFailed(operation: "Send feature report 0x\(String(command, radix: 16))", result)
        }
    }
}

final class InputCallbackContext: @unchecked Sendable {
    let keyCount: Int
    let handler: @Sendable ([Bool]) -> Void
    let buffer: UnsafeMutablePointer<UInt8>

    init(keyCount: Int, handler: @escaping @Sendable ([Bool]) -> Void, buffer: UnsafeMutablePointer<UInt8>) {
        self.keyCount = keyCount
        self.handler = handler
        self.buffer = buffer
    }

    deinit {
        buffer.deallocate()
    }
}

final class KeyboardSynthesizer: @unchecked Sendable {
    private let source = CGEventSource(stateID: .hidSystemState)

    var isTrustedForAccessibility: Bool {
        AXIsProcessTrusted()
    }

    func post(keyCode: CGKeyCode, isDown: Bool) {
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)?
            .post(tap: .cghidEventTap)
    }
}

enum FunctionKeyAction: Sendable {
    case shortcut(keyLabel: String, identifier: String)
    case keyboard(keyCode: CGKeyCode)

    var usesKeyboard: Bool {
        switch self {
        case .keyboard: true
        case .shortcut: false
        }
    }
}

struct ShortcutDefinition: Sendable {
    let name: String
    let identifier: String
    let iconJPEGData: Data?
}

struct ShortcutListEntry: Sendable {
    let keyLabel: String
    let name: String
    let identifier: String
}

final class ShortcutRunner: @unchecked Sendable {
    private let executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")

    func availableShortcutsByKeyLabel() -> [String: ShortcutDefinition] {
        runIconExtractor()
        let entriesByKeyLabel = availableEntriesByKeyLabel()
        return entriesByKeyLabel.mapValues { entry in
            ShortcutDefinition(
                name: entry.name,
                identifier: entry.identifier,
                iconJPEGData: shortcutIconJPEGData(forShortcutName: entry.name)
            )
        }
    }

    private func availableEntriesByKeyLabel() -> [String: ShortcutListEntry] {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["list", "--folder-name", shortcutFolderName, "--show-identifiers"]

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            fputs("Could not list Shortcuts: \(error)\n", stderr)
            return [:]
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                fputs("Could not list Shortcuts: shortcuts exited with status \(process.terminationStatus)\n", stderr)
            } else {
                fputs("Could not list Shortcuts: \(message)\n", stderr)
            }
            return [:]
        }

        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return shortcutEntriesByKeyLabel(in: text)
    }

    private func runIconExtractor() {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["run", iconExtractorShortcutName]

        let errors = Pipe()
        process.standardError = errors

        do {
            try process.run()
        } catch {
            fputs("Could not run icon extractor Shortcut: \(error)\n", stderr)
            return
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                fputs("Icon extractor Shortcut exited with status \(process.terminationStatus)\n", stderr)
            } else {
                fputs("Icon extractor Shortcut failed: \(message)\n", stderr)
            }
            return
        }
    }

    func run(identifier: String) {
        DispatchQueue.global(qos: .userInitiated).async { [executableURL] in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["run", identifier]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    fputs("Shortcut \(identifier) exited with status \(process.terminationStatus)\n", stderr)
                }
            } catch {
                fputs("Could not run Shortcut \(identifier): \(error)\n", stderr)
            }
        }
    }
}

func shortcutIconJPEGData(forShortcutName shortcutName: String) -> Data? {
    let iconURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(shortcutIconsDirectory, isDirectory: true)
        .appendingPathComponent("\(shortcutName).png", isDirectory: false)
    guard
        let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        return nil
    }
    return streamDeckJPEGData(from: image)
}

func streamDeckJPEGData(from image: CGImage) -> Data? {
    let bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
    guard let context = makeStreamDeckImageContext(bounds: bounds) else {
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
    return jpegData(from: rotatedImage)
}

func makeStreamDeckImageContext(bounds: CGRect) -> CGContext? {
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
    return context
}

func jpegData(from image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        return nil
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationLossyCompressionQuality: 0.8,
        kCGImagePropertyJFIFIsProgressive: false
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return data as Data
}

func shortcutEntriesByKeyLabel(in text: String) -> [String: ShortcutListEntry] {
    let pattern = #"(?m)^((F(?:[1-9]|1[0-5]))(?: .*)?) \(([0-9A-Fa-f-]{36})\)$"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
        return [:]
    }

    var entriesByKeyLabel: [String: ShortcutListEntry] = [:]
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    for match in expression.matches(in: text, range: range) {
        guard
            let nameRange = Range(match.range(at: 1), in: text),
            let keyLabelRange = Range(match.range(at: 2), in: text),
            let identifierRange = Range(match.range(at: 3), in: text)
        else {
            continue
        }
        let keyLabel = String(text[keyLabelRange])
        if entriesByKeyLabel[keyLabel] == nil {
            entriesByKeyLabel[keyLabel] = ShortcutListEntry(
                keyLabel: keyLabel,
                name: String(text[nameRange]),
                identifier: String(text[identifierRange])
            )
        } else {
            fputs("Ignoring duplicate Shortcut for \(keyLabel)\n", stderr)
        }
    }
    return entriesByKeyLabel
}

final class FunctionKeyModeState: @unchecked Sendable {
    private let actions: [FunctionKeyAction]
    private let shortcutRunner: ShortcutRunner
    private let synthesizer: KeyboardSynthesizer
    private var previousStates = [Bool](repeating: false, count: keyCount)

    init(actions: [FunctionKeyAction], shortcutRunner: ShortcutRunner, synthesizer: KeyboardSynthesizer) {
        self.actions = actions
        self.shortcutRunner = shortcutRunner
        self.synthesizer = synthesizer
    }

    func handle(_ states: [Bool]) {
        let normalizedStates = normalize(states)
        for index in functionKeys.indices where normalizedStates[index] != previousStates[index] {
            let functionKey = functionKeys[index]
            let isDown = normalizedStates[index]
            fputs("\(functionKey.label) \(isDown ? "down" : "up")\n", stderr)
            handle(action: actions[index], isDown: isDown)
        }
        previousStates = normalizedStates
    }

    func releaseAll() {
        for index in functionKeys.indices where previousStates[index] {
            let functionKey = functionKeys[index]
            fputs("\(functionKey.label) up\n", stderr)
            if case let .keyboard(keyCode) = actions[index] {
                synthesizer.post(keyCode: keyCode, isDown: false)
            }
        }
        previousStates = [Bool](repeating: false, count: keyCount)
    }

    private func handle(action: FunctionKeyAction, isDown: Bool) {
        switch action {
        case let .shortcut(_, identifier):
            if isDown {
                shortcutRunner.run(identifier: identifier)
            }
        case let .keyboard(keyCode):
            synthesizer.post(keyCode: keyCode, isDown: isDown)
        }
    }

    private func normalize(_ states: [Bool]) -> [Bool] {
        var normalizedStates = [Bool](repeating: false, count: keyCount)
        for index in 0..<min(states.count, normalizedStates.count) {
            normalizedStates[index] = states[index]
        }
        return normalizedStates
    }
}

func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
        return nil
    }
    return value as? Int
}

func writeUInt16LE(_ value: UInt16, into bytes: inout [UInt8], at offset: Int) {
    bytes[offset] = UInt8(value & 0x00FF)
    bytes[offset + 1] = UInt8((value >> 8) & 0x00FF)
}
