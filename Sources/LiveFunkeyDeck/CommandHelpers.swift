/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Sources/LiveFunkeyDeck/CommandHelpers.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-08
///

import Foundation

func writeError(_ string: String) {
    let handled = string.utf8.withContiguousStorageIfAvailable { buffer in
        do {
            try FileHandle.standardError.write(contentsOf: UnsafeRawBufferPointer(buffer))
            return true
        } catch {
            return false
        }
    }

    if handled != true, let data = string.data(using: .utf8) {
        try? FileHandle.standardError.write(contentsOf: data)
    }
}

func parseArgs(_ args: ArraySlice<String>) -> (
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
