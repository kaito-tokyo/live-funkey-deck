// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <memory>
#include <type_traits>

#include <CoreFoundation/CFBase.h>
#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDManager.h>

namespace KaitoTokyo::LiveFunkeyDeck {

class UniqueIOHIDManagerPtr {
public:
  explicit UniqueIOHIDManagerPtr(IOHIDManagerRef pointer) : pointer_(pointer, &CFRelease) {}
  ~UniqueIOHIDManagerPtr() noexcept {
    if (opened_) {
      close();
    }
  }

  [[nodiscard]] auto get() const noexcept -> IOHIDManagerRef { return pointer_.get(); }

  auto open(IOOptionBits options) noexcept -> IOReturn {
    IOReturn result = IOHIDManagerOpen(pointer_.get(), options);

    if (result == kIOReturnSuccess) {
      opened_ = true;
      openOptions_ = options;
    }

    return result;
  }

  auto close() noexcept -> IOReturn {
    IOReturn result = IOHIDManagerClose(pointer_.get(), openOptions_);

    if (result == kIOReturnSuccess) {
      opened_ = false;
      openOptions_ = 0;
    }

    return result;
  }

private:
  std::unique_ptr<std::remove_pointer_t<IOHIDManagerRef>, decltype(&CFRelease)> pointer_;
  IOOptionBits openOptions_ = 0;
  bool opened_ = false;
};

} // namespace KaitoTokyo::LiveFunkeyDeck
