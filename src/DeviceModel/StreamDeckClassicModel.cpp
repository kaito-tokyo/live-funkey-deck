// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#include "StreamDeckClassicModel.hpp"

#include <algorithm>
#include <array>
#include <cstring>
#include <iostream>

#include <IOKit/IOReturn.h>

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/hid/IOHIDBase.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDDeviceTypes.h>
#include <optional>
#include <set>

namespace KaitoTokyo::LiveFunkeyDeck {

auto StreamDeckClassicModel::getUnitSerialNumber(IOHIDDeviceRef device) const noexcept -> std::optional<std::string> {
  CFIndex reportLength = 32;
  std::array<std::uint8_t, 32> report{};
  report[0] = 0x06;

  IOReturn result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0x06, report.data(), &reportLength);

  if (result == kIOReturnSuccess && reportLength == 32 && report[0] == 0x06 &&
      (report[1] == 0x0C || report[1] == 0x0E)) {
    return std::string(reinterpret_cast<char *>(report.data()) + 2, report[1]);
  } else {
    std::cerr << "error=getUnitSerialNumberError\tresult=" << result << "\treportLength=" << reportLength
              << "\treport[0]=" << static_cast<int>(report[0]) << "\treport[1]=" << static_cast<int>(report[1]) << '\n';
    std::cerr.flush();
    return std::nullopt;
  }
}

void StreamDeckClassicModel::uploadKeyImage(IOHIDDeviceRef device, std::uint8_t keyIndex,
                                            std::span<const std::uint8_t> keyImageBytes) {
  std::array<std::uint8_t, 1024> report{};

  std::size_t chunkIndex = 0;
  std::size_t byteOffset = 0;
  while (byteOffset < keyImageBytes.size()) {
    std::size_t end = std::min(byteOffset + 1016, keyImageBytes.size());
    std::size_t chunkSize = end - byteOffset;

    report = {};
    report[0] = 0x02;     // Output Report
    report[1] = 0x07;     // Update Key Image
    report[2] = keyIndex; // Key Index

    // Transfer is Done flag
    report[3] = end == keyImageBytes.size() ? 0x01 : 0x00;

    // Chunk Contents Size (Little endian)
    report[4] = static_cast<std::uint8_t>(chunkSize & 0xFF);
    report[5] = static_cast<std::uint8_t>((chunkSize >> 8) & 0xFF);

    // Chunk Index (Little endian)
    report[6] = static_cast<std::uint8_t>(chunkIndex & 0xFF);
    report[7] = static_cast<std::uint8_t>((chunkIndex >> 8) & 0xFF);

    std::memcpy(report.data() + 8, keyImageBytes.data() + byteOffset, chunkSize);

    IOReturn result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x02, report.data(), 1024);
    if (result != kIOReturnSuccess) {
      std::cerr << "WARNING: Failed to update key image of " << keyIndex << ".\n";
      return;
    }

    chunkIndex += 1;
    byteOffset += chunkSize;
  }
}

auto StreamDeckClassicModel::showLogo(IOHIDDeviceRef device) const noexcept -> IOReturn {
  std::array<std::uint8_t, 32> report{};
  report[0] = 0x03;
  report[1] = 0x02;
  return IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x03, report.data(), 32);
}

auto StreamDeckClassicModel::parsePressStateChangeReport(std::uint8_t *report, CFIndex reportLength) const noexcept
    -> std::set<KeyIndex> {
  if (reportLength >= 4 + keyCount_ && report[0] == 0x01 && report[1] == 0x00) {
    std::set<std::uint8_t> pressState;
    for (KeyIndex i = 0; i < keyCount_; i++) {
      if (report[i + 4] == 0x01) {
        pressState.insert(i);
      }
    }
    return pressState;
  } else {
    return {};
  }
}

} // namespace KaitoTokyo::LiveFunkeyDeck
