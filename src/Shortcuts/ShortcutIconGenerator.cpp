// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#include "ShortcutIconGenerator.hpp"

#include <array>
#include <cerrno>
#include <chrono>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <span>
#include <string>
#include <utility>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>

#include <spawn.h>
#include <sys/wait.h>

#include "../Helpers/UniquePosixSpawnFileActions.hpp"

namespace KaitoTokyo::LiveFunkeyDeck {

namespace {

auto keyNameForIndex(std::size_t keyIndex) -> std::string { return "F" + std::to_string(keyIndex + 1); }

auto epochMilliseconds() -> std::int64_t {
  return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch())
      .count();
}

constexpr auto extractIconsShortcutName = "tokyo.kaito.live-funkey-deck.extract-icons";

auto shortcutIconPath(const std::filesystem::path &shortcutIconsDir, const std::string &shortcutName)
    -> std::filesystem::path {
  auto fileName = shortcutName;
  for (auto &character : fileName) {
    if (character == '/') {
      character = ':';
    }
  }

  return shortcutIconsDir / (fileName + ".png");
}

auto readBinaryFile(const std::filesystem::path &path) -> std::optional<std::vector<std::uint8_t>> {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    return std::nullopt;
  }

  std::vector<std::uint8_t> bytes;
  for (std::istreambuf_iterator<char> iterator(file), end; iterator != end; ++iterator) {
    bytes.push_back(static_cast<std::uint8_t>(*iterator));
  }

  if (file.bad()) {
    return std::nullopt;
  }

  return bytes;
}

struct CFReleaser {
  void operator()(CFTypeRef value) const {
    if (value) {
      CFRelease(value);
    }
  }
};

struct CGImageReleaser {
  void operator()(CGImageRef value) const {
    if (value) {
      CGImageRelease(value);
    }
  }
};

struct CGContextReleaser {
  void operator()(CGContextRef value) const {
    if (value) {
      CGContextRelease(value);
    }
  }
};

using UniqueCFDataRef = std::unique_ptr<std::remove_pointer_t<CFDataRef>, CFReleaser>;
using UniqueCFMutableDataRef = std::unique_ptr<std::remove_pointer_t<CFMutableDataRef>, CFReleaser>;
using UniqueCFDictionaryRef = std::unique_ptr<std::remove_pointer_t<CFDictionaryRef>, CFReleaser>;
using UniqueCFNumberRef = std::unique_ptr<std::remove_pointer_t<CFNumberRef>, CFReleaser>;
using UniqueCGColorSpaceRef = std::unique_ptr<std::remove_pointer_t<CGColorSpaceRef>, decltype(&CGColorSpaceRelease)>;
using UniqueCGImageSourceRef = std::unique_ptr<std::remove_pointer_t<CGImageSourceRef>, CFReleaser>;
using UniqueCGImageDestinationRef = std::unique_ptr<std::remove_pointer_t<CGImageDestinationRef>, CFReleaser>;
using UniqueCGImageRef = std::unique_ptr<std::remove_pointer_t<CGImageRef>, CGImageReleaser>;
using UniqueCGContextRef = std::unique_ptr<std::remove_pointer_t<CGContextRef>, CGContextReleaser>;

auto jpegCompressionProperties() -> UniqueCFDictionaryRef {
  constexpr double quality = 0.8;
  UniqueCFNumberRef qualityNumber(CFNumberCreate(nullptr, kCFNumberDoubleType, &quality));
  if (!qualityNumber) {
    return nullptr;
  }

  const void *keys[] = {kCGImageDestinationLossyCompressionQuality};
  const void *values[] = {qualityNumber.get()};
  return UniqueCFDictionaryRef(CFDictionaryCreate(nullptr, keys, values, 1, &kCFTypeDictionaryKeyCallBacks,
                                                  &kCFTypeDictionaryValueCallBacks));
}

auto rotateImageAsJpeg(std::span<const std::uint8_t> sourceBytes, std::size_t width, std::size_t height, double rotate,
                       std::string_view keyName, bool debug)
    -> std::optional<std::vector<std::uint8_t>> {
  UniqueCFDataRef sourceData(CFDataCreate(nullptr, sourceBytes.data(), static_cast<CFIndex>(sourceBytes.size())));
  if (!sourceData) {
    return std::nullopt;
  }

  UniqueCGImageSourceRef source(CGImageSourceCreateWithData(sourceData.get(), nullptr));
  if (!source) {
    return std::nullopt;
  }

  UniqueCGImageRef sourceImage(CGImageSourceCreateImageAtIndex(source.get(), 0, nullptr));
  if (!sourceImage) {
    return std::nullopt;
  }
  if (debug) {
    std::cout << "DEBUG=shortcutIconDecoded\tkeyName=" << keyName << "\tepochMs=" << epochMilliseconds() << '\n';
  }

  UniqueCGColorSpaceRef colorSpace(CGColorSpaceCreateWithName(kCGColorSpaceSRGB), CGColorSpaceRelease);
  if (!colorSpace) {
    colorSpace.reset(CGColorSpaceCreateDeviceRGB());
  }
  if (!colorSpace) {
    return std::nullopt;
  }

  UniqueCGContextRef context(CGBitmapContextCreate(nullptr, width, height, 8, 0, colorSpace.get(),
                                                  kCGImageAlphaNoneSkipLast));
  if (!context) {
    return std::nullopt;
  }

  auto rect = CGRectMake(0, 0, static_cast<CGFloat>(width), static_cast<CGFloat>(height));
  CGContextSetGrayFillColor(context.get(), 0, 1);
  CGContextFillRect(context.get(), rect);
  CGContextSaveGState(context.get());
  CGContextTranslateCTM(context.get(), static_cast<CGFloat>(width), static_cast<CGFloat>(height));
  CGContextRotateCTM(context.get(), static_cast<CGFloat>(rotate));
  CGContextDrawImage(context.get(), rect, sourceImage.get());
  CGContextRestoreGState(context.get());

  UniqueCGImageRef rotatedImage(CGBitmapContextCreateImage(context.get()));
  if (!rotatedImage) {
    return std::nullopt;
  }
  if (debug) {
    std::cout << "DEBUG=shortcutIconRotated\tkeyName=" << keyName << "\tepochMs=" << epochMilliseconds() << '\n';
  }

  UniqueCFMutableDataRef destinationData(CFDataCreateMutable(nullptr, 0));
  if (!destinationData) {
    return std::nullopt;
  }

  UniqueCGImageDestinationRef destination(CGImageDestinationCreateWithData(destinationData.get(), CFSTR("public.jpeg"),
                                                                          1, nullptr));
  if (!destination) {
    return std::nullopt;
  }

  auto properties = jpegCompressionProperties();
  CGImageDestinationAddImage(destination.get(), rotatedImage.get(), properties.get());
  if (!CGImageDestinationFinalize(destination.get())) {
    return std::nullopt;
  }
  if (debug) {
    std::cout << "DEBUG=shortcutIconEncoded\tkeyName=" << keyName << "\tepochMs=" << epochMilliseconds()
              << "\tbyteCount=" << CFDataGetLength(destinationData.get()) << '\n';
  }

  auto byteCount = CFDataGetLength(destinationData.get());
  auto bytes = CFDataGetBytePtr(destinationData.get());
  return std::vector<std::uint8_t>(bytes, bytes + byteCount);
}

} // namespace

auto startExtractShortcutIcons(const std::filesystem::path &shortcutIconsDir, bool debug) -> std::optional<pid_t> {
  if (debug) {
    std::cout << "DEBUG=extractShortcutIconsStarted\tepochMs=" << epochMilliseconds()
              << "\tshortcutName=" << extractIconsShortcutName << "\toutputPath=" << shortcutIconsDir << '\n';
  }

  auto outputPath = shortcutIconsDir.string();
  std::array<const char *, 6> argv{
      "/usr/bin/shortcuts",
      "run",
      extractIconsShortcutName,
      "--output-path",
      outputPath.c_str(),
      nullptr,
  };

  UniquePosixSpawnFileActions actions;
  actions.attachStdoutToStderr();

  if (pid_t pid = 0;
      posix_spawn(&pid, argv[0], actions.get(), nullptr, const_cast<char *const *>(argv.data()), nullptr) == 0) {
    return pid;
  }

  return std::nullopt;
}

auto shortcutIconsAvailable(const std::vector<std::optional<std::string>> &shortcutByKeyIndex,
                            const std::filesystem::path &shortcutIconsDir, std::size_t keyCount, bool debug) -> bool {
  for (std::size_t keyIndex = 0; keyIndex < keyCount && keyIndex < shortcutByKeyIndex.size(); keyIndex++) {
    const auto &shortcutName = shortcutByKeyIndex[keyIndex];
    if (!shortcutName) {
      continue;
    }

    auto iconPath = shortcutIconPath(shortcutIconsDir, *shortcutName);
    std::error_code error;
    if (!std::filesystem::is_regular_file(iconPath, error)) {
      if (debug) {
        std::cout << "DEBUG=shortcutIconMissing\tkeyName=" << keyNameForIndex(keyIndex)
                  << "\tepochMs=" << epochMilliseconds() << "\tpath=" << iconPath << '\n';
      }
      return false;
    }

    if (debug) {
      std::cout << "DEBUG=shortcutIconAvailable\tkeyName=" << keyNameForIndex(keyIndex)
                << "\tepochMs=" << epochMilliseconds() << "\tpath=" << iconPath << '\n';
    }
  }

  return true;
}

auto generateShortcutKeyImages(const std::vector<std::optional<std::string>> &shortcutByKeyIndex,
                               const std::filesystem::path &shortcutIconsDir, std::size_t keyCount, std::size_t width,
                               std::size_t height, double rotate, bool debug)
    -> ShortcutKeyImages {
  if (debug) {
    std::cout << "DEBUG=generateShortcutKeyImagesStarted\tepochMs=" << epochMilliseconds() << "\tkeyCount="
              << keyCount << "\twidth=" << width << "\theight=" << height << "\trotate=" << rotate << '\n';
  }

  ShortcutKeyImages keyImages(keyCount);

  for (std::size_t keyIndex = 0; keyIndex < keyCount && keyIndex < shortcutByKeyIndex.size(); keyIndex++) {
    const auto &shortcutName = shortcutByKeyIndex[keyIndex];
    if (!shortcutName) {
      continue;
    }

    auto iconPath = shortcutIconPath(shortcutIconsDir, *shortcutName);
    if (auto keyImage = readBinaryFile(iconPath)) {
      if (debug) {
        std::cout << "DEBUG=shortcutIconRead\tkeyName=" << keyNameForIndex(keyIndex)
                  << "\tepochMs=" << epochMilliseconds() << "\tbyteCount=" << keyImage->size() << "\tpath="
                  << iconPath << '\n';
      }

      if (auto rotatedKeyImage = rotateImageAsJpeg(*keyImage, width, height, rotate, keyNameForIndex(keyIndex), debug)) {
        keyImages[keyIndex] = std::move(*rotatedKeyImage);
        std::cout << "INFO=shortcutIconLoaded\tkeyName=" << keyNameForIndex(keyIndex) << "\tpath=" << iconPath
                  << '\n';
      } else {
        std::cerr << "WARNING: Failed to rotate shortcut icon\tkeyName=" << keyNameForIndex(keyIndex)
                  << "\tpath=" << iconPath << '\n';
      }
    } else {
      std::cerr << "WARNING: Failed to read shortcut icon\tkeyName=" << keyNameForIndex(keyIndex)
                << "\tpath=" << iconPath << '\n';
    }
  }

  if (debug) {
    std::cout << "DEBUG=generateShortcutKeyImagesFinished\tepochMs=" << epochMilliseconds() << '\n';
  }
  return keyImages;
}

} // namespace KaitoTokyo::LiveFunkeyDeck
