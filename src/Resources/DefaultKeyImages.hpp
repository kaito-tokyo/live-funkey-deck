// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <array>
#include <cstdint>
#include <span>

namespace KaitoTokyo::LiveFunkeyDeck {

auto defaultKeyImages() -> const std::array<std::span<const std::uint8_t>, 15> &;

} // namespace KaitoTokyo::LiveFunkeyDeck
