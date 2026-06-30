// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#include "DefaultKeyImages.hpp"

namespace KaitoTokyo::LiveFunkeyDeck {
namespace {

constexpr std::uint8_t f1Rot180Jpg[] = {
#embed "f1_rot180.jpg"
};
constexpr std::uint8_t f2Rot180Jpg[] = {
#embed "f2_rot180.jpg"
};
constexpr std::uint8_t f3Rot180Jpg[] = {
#embed "f3_rot180.jpg"
};
constexpr std::uint8_t f4Rot180Jpg[] = {
#embed "f4_rot180.jpg"
};
constexpr std::uint8_t f5Rot180Jpg[] = {
#embed "f5_rot180.jpg"
};
constexpr std::uint8_t f6Rot180Jpg[] = {
#embed "f6_rot180.jpg"
};
constexpr std::uint8_t f7Rot180Jpg[] = {
#embed "f7_rot180.jpg"
};
constexpr std::uint8_t f8Rot180Jpg[] = {
#embed "f8_rot180.jpg"
};
constexpr std::uint8_t f9Rot180Jpg[] = {
#embed "f9_rot180.jpg"
};
constexpr std::uint8_t f10Rot180Jpg[] = {
#embed "f10_rot180.jpg"
};
constexpr std::uint8_t f11Rot180Jpg[] = {
#embed "f11_rot180.jpg"
};
constexpr std::uint8_t f12Rot180Jpg[] = {
#embed "f12_rot180.jpg"
};
constexpr std::uint8_t f13Rot180Jpg[] = {
#embed "f13_rot180.jpg"
};
constexpr std::uint8_t f14Rot180Jpg[] = {
#embed "f14_rot180.jpg"
};
constexpr std::uint8_t f15Rot180Jpg[] = {
#embed "f15_rot180.jpg"
};

constexpr std::array<std::span<const std::uint8_t>, 15> images{
    std::span{f1Rot180Jpg},
    std::span{f2Rot180Jpg},
    std::span{f3Rot180Jpg},
    std::span{f4Rot180Jpg},
    std::span{f5Rot180Jpg},
    std::span{f6Rot180Jpg},
    std::span{f7Rot180Jpg},
    std::span{f8Rot180Jpg},
    std::span{f9Rot180Jpg},
    std::span{f10Rot180Jpg},
    std::span{f11Rot180Jpg},
    std::span{f12Rot180Jpg},
    std::span{f13Rot180Jpg},
    std::span{f14Rot180Jpg},
    std::span{f15Rot180Jpg},
};

} // namespace

auto defaultKeyImages() -> const std::array<std::span<const std::uint8_t>, 15> & { return images; }

} // namespace KaitoTokyo::LiveFunkeyDeck
