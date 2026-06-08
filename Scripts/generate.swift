#!/usr/bin/env swift
/// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
///
/// SPDX-License-Identifier: Apache-2.0
///
/// Scripts/generate.swift
/// LiveFunkeyDeck
///
/// Version: 1.0.0
/// Date: 2026-06-06
///

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDir = "Sources/LiveFunkeyDeck/Resources"
let bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
let fgColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
let bgColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
let fontName = "NotoSans-Bold"
let fontSize: CGFloat = 32

let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
let actualFontName = CTFontCopyPostScriptName(font) as String
print("Font: \(actualFontName)")
if actualFontName != fontName {
    print("WARNING: Alternative font was selected!")
}

func makeContext() -> CGContext {
    return CGContext(
        data: nil,
        width: Int(bounds.size.width),
        height: Int(bounds.size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
}

for index in 1...15 {
    let label = "F\(index)"
    let fileURL = URL(fileURLWithPath: "\(outputDir)/f\(index)_rot180.jpg", isDirectory: false)

    let context = makeContext()

    // Background fill
    context.setFillColor(bgColor)
    context.fill(bounds)

    // Foreground text
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(
            nil,
            label as CFString,
            [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: fgColor,
            ] as CFDictionary
        )!)
    let textBounds = CTLineGetImageBounds(line, context)
    context.textMatrix = .identity
    context.textPosition = CGPoint(
        x: (bounds.width - textBounds.width) / 2 - textBounds.origin.x,
        y: (bounds.height - textBounds.height) / 2 - textBounds.origin.y
    )
    CTLineDraw(line, context)

    let image = context.makeImage()!

    // Rotate 180
    let rotateContext = makeContext()

    rotateContext.translateBy(x: bounds.width, y: bounds.height)
    rotateContext.rotate(by: .pi)
    rotateContext.draw(image, in: bounds)

    let rotatedImage = rotateContext.makeImage()!

    // Output JPEG
    let destination = CGImageDestinationCreateWithURL(
        fileURL as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    )!

    CGImageDestinationAddImage(
        destination, rotatedImage,
        [
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImagePropertyJFIFIsProgressive: false,
        ] as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to create \(fileURL.path(percentEncoded: false))")
    }

    print("Generated: \(fileURL.path(percentEncoded: false))")
}
