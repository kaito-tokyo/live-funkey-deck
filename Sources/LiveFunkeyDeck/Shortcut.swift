/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Sources/LiveFunkeyDeck/Shortcut.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-08
///

import Foundation

enum ShortcutError: Error {
    case exitFailure(Int32)
}

extension ShortcutError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .exitFailure(let code):
            "Shortcut failed with exit code \(code)."
        }
    }
}

struct Shortcut {
    let name: String
    let identifier: String

    func runAndWait(
        process: Process, inputPath: String? = nil, outputPath: String? = nil
    ) throws {
        var arguments = ["run", identifier]
        if let inputPath {
            arguments.append("--input-path")
            arguments.append(inputPath)
        }
        if let outputPath {
            arguments.append("--output-path")
            arguments.append(outputPath)
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ShortcutError.exitFailure(process.terminationStatus)
        }
    }

    func runAndForget(process: Process, inputPath: String? = nil, outputPath: String? = nil) {
        let shortcut = self
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try shortcut.runAndWait(
                    process: process, inputPath: inputPath, outputPath: outputPath)
            } catch {
                writeError(
                    "WARNING: Failed to run shortcut \(shortcut.name). \(error.localizedDescription)\n"
                )
            }
        }
    }
}

extension Shortcut {
    static func listFolders(standardError: Any? = nil) throws -> [String: String] {
        let standardOutput = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list", "--folders", "--show-identifiers"]
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        let outputData = try standardOutput.fileHandleForReading.readToEnd()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ShortcutError.exitFailure(process.terminationStatus)
        }

        guard
            let outputData,
            let output = String(data: outputData, encoding: .utf8)
        else {
            return [:]
        }

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)

        var folders: [String: String] = [:]
        for line in lines {
            guard let m = line.wholeMatch(of: /(.*) \(([-0-9A-Za-z]+)\)/) else {
                writeError(
                    "WARNING: Malformed shortcut folder line. Output line MUST follow the form of `NAME (UUID)`.\n"
                )
                continue
            }

            let name = String(m.output.1)
            let identifier = String(m.output.2)

            guard folders[name] == nil else {
                writeError(
                    "WARNING: Ignoring duplicate shortcut folder. name=\(name) identifier=\(identifier).\n"
                )
                continue
            }

            folders[name] = identifier
        }

        return folders
    }

    static func listShortcuts(in folderName: String? = nil, standardError: Any? = nil) throws
        -> [String: Shortcut]
    {
        let standardOutput = Pipe()

        var arguments = ["list", "--show-identifiers"]
        if let folderName {
            arguments.append("--folder-name")
            arguments.append(folderName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        let outputData = try standardOutput.fileHandleForReading.readToEnd()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ShortcutError.exitFailure(process.terminationStatus)
        }

        guard
            let outputData,
            let output = String(data: outputData, encoding: .utf8)
        else {
            return [:]
        }

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)

        var shortcuts: [String: Shortcut] = [:]
        for line in lines {
            guard let m = line.wholeMatch(of: /(.*) \(([-0-9A-Za-z]+)\)/) else {
                writeError(
                    "WARNING: Malformed shortcut line. Output line MUST follow the form of `NAME (UUID)`.\n"
                )
                continue
            }

            let name = String(m.output.1)
            let identifier = String(m.output.2)

            guard shortcuts[name] == nil else {
                writeError(
                    "WARNING: Ignoring duplicate shortcut. name=\(name) identifier=\(identifier).\n"
                )
                continue
            }

            shortcuts[name] = Shortcut(name: name, identifier: identifier)

        }

        return shortcuts
    }
}
