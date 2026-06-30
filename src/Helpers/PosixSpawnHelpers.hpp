// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <cerrno>
#include <memory>
#include <vector>

#include <sys/wait.h>
#include <unistd.h>

namespace KaitoTokyo::LiveFunkeyDeck {

class ChildProcess {
public:
  explicit ChildProcess(pid_t pid) : pid_(pid) {}
  virtual ~ChildProcess() = default;

  ChildProcess(const ChildProcess &) = delete;
  auto operator=(const ChildProcess &) -> ChildProcess & = delete;
  ChildProcess(ChildProcess &&) = delete;
  auto operator=(ChildProcess &&) -> ChildProcess & = delete;

  auto pid() const -> pid_t { return pid_; }
  virtual void onExit(int) {}

private:
  pid_t pid_;
};

using ChildProcesses = std::vector<std::unique_ptr<ChildProcess>>;

void waitForChildProcesses(ChildProcesses &childProcesses, int options) {
  for (auto &childProcess : childProcesses) {
    int status = 0;
    while (waitpid(childProcess->pid(), &status, options) < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }

    childProcess->onExit(status);
  }
  childProcesses.clear();
}

void reapFinishedChildProcesses(ChildProcesses &childProcesses) {
  std::erase_if(childProcesses, [](const std::unique_ptr<ChildProcess> &childProcess) {
    int status = 0;
    while (true) {
      auto result = waitpid(childProcess->pid(), &status, WNOHANG);
      if (result == childProcess->pid()) {
        childProcess->onExit(status);
        return true;
      }
      if (result == 0) {
        return false;
      }
      if (errno == EINTR) {
        continue;
      }
      return true;
    }
  });
}

} // namespace KaitoTokyo::LiveFunkeyDeck
