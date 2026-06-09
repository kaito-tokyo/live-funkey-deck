---
# SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
#
# SPDX-License-Identifier: Apache-2.0

# file: .github/instructions/swift6.instructions.md
# author: Kaito Udagawa <umireon@kaito.tokyo>
# version: 1.0.0
# date: 2026-06-09

applyTo: "{Package.swift,Scripts/**/*.swift,Sources/**/*.swift}"
---

This project uses Swift 6.

- UnsafeMutablePointer has `update(repeating:count:)`. Introduced in Swift 5.8.
