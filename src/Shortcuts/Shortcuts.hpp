// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <array>
#include <cerrno>
#include <cstddef>
#include <optional>
#include <regex>
#include <string>
#include <string_view>
#include <vector>

#include <spawn.h>
#include <sys/wait.h>

#include "../Helpers/UniquePosixPipe.hpp"
#include "../Helpers/UniquePosixSpawnFileActions.hpp"

namespace KaitoTokyo::LiveFunkeyDeck {

auto listShortcutsInFolder(const char *folderName) -> std::vector<std::string> {
  std::array<const char *, 5> argv{
      "/usr/bin/shortcuts", "list", "--folder-name", folderName, nullptr,
  };

  UniquePosixPipe pipe;
  UniquePosixSpawnFileActions actions;
  actions.attachPipeToStdout(pipe);

  pid_t pid = 0;
  if (posix_spawn(&pid, argv[0], actions.get(), nullptr, const_cast<char *const *>(argv.data()), nullptr) == 0) {
    std::string output = pipe.readToEOF();

    int status = 0;
    while (waitpid(pid, &status, 0) < 0) {
      if (errno == EINTR) {
        continue;
      }
      return {};
    }

    std::vector<std::string> shortcutNames;
    std::string_view tail(output);
    while (!tail.empty()) {
      auto pos = tail.find('\n');

      if (pos == std::string_view::npos) {
        shortcutNames.emplace_back(tail);
        break;
      } else {
        shortcutNames.emplace_back(tail.substr(0, pos));
        tail.remove_prefix(pos + 1);
      }
    }

    return shortcutNames;
  }

  return {};
}

auto parseShortcutKeyIndex(const std::string &shortcutName) -> std::optional<int> {
  static const std::regex keyNamePattern("F[1-9][0-9]? ");
  std::smatch match;
  if (!std::regex_search(shortcutName, match, keyNamePattern, std::regex_constants::match_continuous)) {
    return std::nullopt;
  }

  int keyNumber = shortcutName[1] - '0';
  if (match.length() == 4) {
    keyNumber = keyNumber * 10 + (shortcutName[2] - '0');
  }

  return keyNumber - 1;
}

auto keyNameForIndex(int keyIndex) -> std::string { return "F" + std::to_string(keyIndex + 1); }

auto runShortcut(const std::string &shortcutName) -> std::optional<pid_t> {
  std::array<const char *, 4> argv{
      "/usr/bin/shortcuts",
      "run",
      shortcutName.c_str(),
      nullptr,
  };

  if (pid_t pid = 0;
      posix_spawn(&pid, argv[0], nullptr, nullptr, const_cast<char *const *>(argv.data()), nullptr) == 0) {
    return pid;
  }

  return std::nullopt;
}

} // namespace KaitoTokyo::LiveFunkeyDeck
