// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <cstdint>
#include <optional>
#include <set>
#include <span>
#include <string>

#include <CoreFoundation/CFBase.h>
#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDDeviceTypes.h>

namespace KaitoTokyo::LiveFunkeyDeck {

class StreamDeckClassicModel {
public:
  using KeyIndex = std::uint8_t;

  StreamDeckClassicModel(KeyIndex keyCount, std::array<std::int32_t, 2> dimension, double rotate) noexcept
      : keyCount_(keyCount), dimension_(dimension), rotate_(rotate) {}
  ~StreamDeckClassicModel() noexcept = default;

  StreamDeckClassicModel(const StreamDeckClassicModel &) = delete;
  auto operator=(const StreamDeckClassicModel &) -> StreamDeckClassicModel & = delete;
  StreamDeckClassicModel(StreamDeckClassicModel &&) = delete;
  auto operator=(StreamDeckClassicModel &&) -> StreamDeckClassicModel & = delete;

  auto keyCount() -> KeyIndex { return keyCount_; }
  auto width() -> std::int32_t { return dimension_[0]; }
  auto height() -> std::int32_t { return dimension_[1]; }
  auto rotate() -> double { return rotate_; }

  auto getUnitSerialNumber(IOHIDDeviceRef device) const noexcept -> std::optional<std::string>;
  auto showLogo(IOHIDDeviceRef device) const noexcept -> IOReturn;
  void uploadKeyImage(IOHIDDeviceRef device, std::uint8_t keyIndex, std::span<const std::uint8_t> keyImageBytes);
  auto parsePressStateChangeReport(std::uint8_t *report, CFIndex reportLength) const noexcept -> std::set<KeyIndex>;

private:
  const KeyIndex keyCount_;
  const std::array<std::int32_t, 2> dimension_;
  const double rotate_;
};

} // namespace KaitoTokyo::LiveFunkeyDeck
