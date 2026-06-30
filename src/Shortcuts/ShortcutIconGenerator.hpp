// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include <unistd.h>

namespace KaitoTokyo::LiveFunkeyDeck {

using ShortcutKeyImages = std::vector<std::optional<std::vector<std::uint8_t>>>;

auto startExtractShortcutIcons(const std::filesystem::path &shortcutIconsDir, bool debug) -> std::optional<pid_t>;

auto shortcutIconsAvailable(const std::vector<std::optional<std::string>> &shortcutByKeyIndex,
                            const std::filesystem::path &shortcutIconsDir, std::size_t keyCount, bool debug) -> bool;

auto generateShortcutKeyImages(const std::vector<std::optional<std::string>> &shortcutByKeyIndex,
                               const std::filesystem::path &shortcutIconsDir, std::size_t keyCount, std::size_t width,
                               std::size_t height, double rotate, bool debug)
    -> ShortcutKeyImages;

} // namespace KaitoTokyo::LiveFunkeyDeck
