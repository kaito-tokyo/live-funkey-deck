// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <cassert>
#include <memory>
#include <type_traits>

#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFNumber.h>

namespace KaitoTokyo::LiveFunkeyDeck {

[[nodiscard]] inline auto createCFArray(auto values) -> CFArrayRef {
  return CFArrayCreate(nullptr, values.data(), static_cast<CFIndex>(values.size()), &kCFTypeArrayCallBacks);
}

[[nodiscard]] inline auto makeCFArray(auto values)
    -> std::unique_ptr<std::remove_pointer_t<CFArrayRef>, decltype(&CFRelease)> {
  return {createCFArray(values), &CFRelease};
}

[[nodiscard]] inline auto createCFDictionary(auto keys, auto values) -> CFDictionaryRef {
  assert(keys.size() == values.size());
  return CFDictionaryCreate(nullptr, keys.data(), values.data(), static_cast<CFIndex>(values.size()),
                            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

[[nodiscard]] inline auto makeCFDictionary(auto keys, auto values)
    -> std::unique_ptr<std::remove_pointer_t<CFDictionaryRef>, decltype(&CFRelease)> {
  return {createCFDictionary(keys, values), &CFRelease};
}

[[nodiscard]] inline auto createCFNumber(long long value) -> CFNumberRef {
  return CFNumberCreate(nullptr, kCFNumberLongLongType, &value);
}

[[nodiscard]] inline auto makeCFNumber(long long value)
    -> std::unique_ptr<std::remove_pointer_t<CFNumberRef>, decltype(&CFRelease)> {
  return {createCFNumber(value), &CFRelease};
}

} // namespace KaitoTokyo::LiveFunkeyDeck
