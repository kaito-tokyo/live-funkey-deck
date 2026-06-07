// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
//  Sources/LiveFunkeyDeck/ShortcutHandler.swift
//  LiveFunkeyDeck
//
//  Version: 1.0.0
//  Date: 2026-06-07
//

import Foundation

struct ShortcutRunner {
    let name: String
    let identifier: String?
    let key: String?

    init(name: String, identifier: String? = nil, key: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.key = key
    }

    func runAndWait() -> Result<Void, any Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", identifier ?? name]
        do {
            try process.run()
            process.waitUntilExit()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func runAndForget() {
        let shortcut = self
        DispatchQueue.global(qos: .userInitiated).async {
            _ = shortcut.runAndWait()
        }
    }

    static func listKeyShortcuts(in folder: String) -> [ShortcutRunner] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list", "--folder-name", folder, "--show-identifiers"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        do {
            try process.run()
            process.waitUntilExit()
            guard
                let outputData = try outputPipe.fileHandleForReading.readToEnd(),
                let output = String(data: outputData, encoding: .utf8)
            else {
                return []
            }
            return output.split(separator: "\n", omittingEmptySubsequences: true).compactMap {
                line -> ShortcutRunner? in
                print(line)
                guard
                    let m = String(line).wholeMatch(
                        of: /(([0-9A-Za-z]+)(?: .*)?) \(([-0-9A-Za-z]+)\)/)
                else {
                    return nil
                }

                return ShortcutRunner(
                    name: String(m.output.1),
                    identifier: String(m.output.3),
                    key: String(m.output.2)
                )
            }
        } catch {
            return []
        }
    }
}
