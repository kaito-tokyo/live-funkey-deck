// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <array>
#include <stdexcept>
#include <string>

#include <unistd.h>

namespace KaitoTokyo::LiveFunkeyDeck {

class UniquePosixPipe {
public:
  UniquePosixPipe() {
    if (pipe(fd_.data()) != 0) {
      throw std::runtime_error("pipe failed");
    }
  }

  ~UniquePosixPipe() noexcept {
    closeReadEndFd();
    closeWriteEndFd();
  }

  UniquePosixPipe(const UniquePosixPipe &) = delete;
  auto operator=(const UniquePosixPipe &) -> UniquePosixPipe & = delete;
  UniquePosixPipe(UniquePosixPipe &&) = delete;
  auto operator=(UniquePosixPipe &&) -> UniquePosixPipe & = delete;

  [[nodiscard]] auto readEndFd() const -> int { return fd_[0]; }
  [[nodiscard]] auto writeEndFd() const -> int { return fd_[1]; }

  void closeReadEndFd() {
    if (fd_[0] >= 0) {
      close(fd_[0]);
      fd_[0] = -1;
    }
  }

  void closeWriteEndFd() {
    if (fd_[1] >= 0) {
      close(fd_[1]);
      fd_[1] = -1;
    }
  }

  auto readToEOF() -> std::string {
    closeWriteEndFd();

    std::string output;
    std::array<char, 4096> buffer{};
    while (true) {
      ssize_t n = read(readEndFd(), buffer.data(), buffer.size());

      if (n > 0) {
        output.append(buffer.data(), static_cast<std::size_t>(n));
        // NOLINTNEXTLINE(bugprone-branch-clone)
      } else if (n == 0) {
        break;
      } else if (errno == EINTR) {
        continue;
      } else {
        break;
      }
    }

    return output;
  }

private:
  std::array<int, 2> fd_{-1, -1};
};

} // namespace KaitoTokyo::LiveFunkeyDeck
