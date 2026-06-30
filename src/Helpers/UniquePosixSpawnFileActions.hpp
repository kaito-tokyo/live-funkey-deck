// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdexcept>

#include <spawn.h>
#include <unistd.h>

#include "UniquePosixPipe.hpp"

namespace KaitoTokyo::LiveFunkeyDeck {

class UniquePosixSpawnFileActions {
public:
  UniquePosixSpawnFileActions() {
    if (posix_spawn_file_actions_init(&actions_) != 0) {
      throw std::runtime_error("posix_spawn_file_actions_init failed");
    }
  }
  ~UniquePosixSpawnFileActions() noexcept { posix_spawn_file_actions_destroy(&actions_); }

  UniquePosixSpawnFileActions(const UniquePosixSpawnFileActions &) = delete;
  auto operator=(const UniquePosixSpawnFileActions &) -> UniquePosixSpawnFileActions & = delete;
  UniquePosixSpawnFileActions(UniquePosixSpawnFileActions &&) = delete;
  auto operator=(UniquePosixSpawnFileActions &&) -> UniquePosixSpawnFileActions & = delete;

  auto get() -> posix_spawn_file_actions_t * { return &actions_; }

  void attachStdoutToStderr() {
    if (posix_spawn_file_actions_adddup2(&actions_, STDERR_FILENO, STDOUT_FILENO) != 0) {
      throw std::runtime_error("posix_spawn_file_actions_adddup2 stderr failed");
    }
  }

  void attachPipeToStdout(UniquePosixPipe &pipe) {
    if (posix_spawn_file_actions_adddup2(&actions_, pipe.writeEndFd(), STDOUT_FILENO) != 0) {
      throw std::runtime_error("posix_spawn_file_actions_adddup2 failed");
    }

    if (posix_spawn_file_actions_addclose(&actions_, pipe.readEndFd()) != 0) {
      throw std::runtime_error("posix_spawn_file_actions_addclose read end failed");
    }

    if (posix_spawn_file_actions_addclose(&actions_, pipe.writeEndFd()) != 0) {
      throw std::runtime_error("posix_spawn_file_actions_addclose write end failed");
    }
  }

private:
  posix_spawn_file_actions_t actions_;
};

} // namespace KaitoTokyo::LiveFunkeyDeck
