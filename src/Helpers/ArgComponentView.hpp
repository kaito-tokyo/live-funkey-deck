// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <string_view>

namespace KaitoTokyo::LiveFunkeyDeck {

class ArgComponentView {
public:
  ArgComponentView(std::string_view arg) : sv_(arg) {}

  auto consumePrefix(std::string_view prefix) -> bool {
    if (sv_.starts_with(prefix)) {
      sv_.remove_prefix(prefix.size());
      return true;
    } else {
      return false;
    }
  }

  auto consumeLongOptionName(std::string_view name) -> bool {
    if (sv_.starts_with(name)) {
      if (sv_.size() == name.size()) {
        sv_.remove_prefix(name.size());
        return true;
      } else if (sv_.size() > name.size() && sv_[name.size()] == '=') {
        sv_.remove_prefix(name.size() + 1);
        return true;
      }
    }

    return false;
  }

  auto consumeValue(auto &value, char *optarg) -> std::optional<int> {
    if (!sv_.empty()) {
      value = sv_;
      return 0;
    } else if (!optarg || (optarg[0] == '-' && optarg[1] == '-')) {
      return std::nullopt;
    } else {
      value = optarg;
      return 1;
    }
  }

  std::string_view sv_;
};

} // namespace KaitoTokyo::LiveFunkeyDeck
