// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

// clang-format off
#include <cmath>
#define LFD_IDENTIFIER "tokyo.kaito.live-funkey-deck"
#define LFD_VERSION "1.0.0"
#define LFD_USAGE \
  "live-funkey-deck " LFD_VERSION ": A small command-line utility for streamer key devices.\n" \
  "Usage: live-funkey-deck [--help] [--version] [options]\n" \
  "  --debug                 Print detailed debug logs.\n" \
  "  --shortcut-folder=NAME  Shortcut folder name to use. Defaults to live-funkey-deck.\n" \
  "  --serial-number=STRING  Serial number to select device. Optional when a single device is connected.\n" \
  "  --licenses              Print licenses and exit."
#define LFD_COPYRIGHT "Copyright 2026 Kaito Udagawa. Licensed under the Apache License, Version 2.0."
// clang-format on

#include <array>
#include <chrono>
#include <csignal>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <dispatch/dispatch.h>
#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>
#include <set>
#include <span>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

#include <sysexits.h>

#include <sys/wait.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFSet.h>

#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDDeviceKeys.h>
#include <IOKit/hid/IOHIDDeviceTypes.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDManager.h>

#include "Helpers/ArgComponentView.hpp"
#include "Helpers/CFHelpers.hpp"
#include "Helpers/IOKitHelpers.hpp"
#include "Helpers/PosixSpawnHelpers.hpp"

#include "DeviceModel/StreamDeckClassicModel.hpp"

#include "Shortcuts/ShortcutIconGenerator.hpp"
#include "Shortcuts/Shortcuts.hpp"

#include "Resources/DefaultKeyImages.hpp"

namespace KaitoTokyo::LiveFunkeyDeck {

auto epochMilliseconds() -> std::int64_t {
  return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch())
      .count();
}

auto applicationSupportDirectory() -> std::optional<std::filesystem::path> {
  if (auto home = std::getenv("HOME")) {
    return std::filesystem::path(home) / "Library" / "Application Support";
  }

  return std::nullopt;
}

void uploadKeyImages(StreamDeckClassicModel &deviceModel, IOHIDDeviceRef device, const ShortcutKeyImages &keyImages,
                     bool debug) {
  auto keyCount = std::min<std::size_t>(deviceModel.keyCount(), defaultKeyImages().size());
  if (debug) {
    std::cout << "DEBUG=uploadKeyImagesStarted\tepochMs=" << epochMilliseconds() << "\tkeyCount=" << keyCount
              << '\n';
  }

  for (std::size_t keyIndex = 0; keyIndex < keyCount; keyIndex++) {
    std::span<const std::uint8_t> keyImage = defaultKeyImages()[keyIndex];
    if (keyIndex < keyImages.size() && keyImages[keyIndex]) {
      keyImage = std::span<const std::uint8_t>(*keyImages[keyIndex]);
    }

    deviceModel.uploadKeyImage(device, static_cast<std::uint8_t>(keyIndex), keyImage);
    std::cout << "INFO=keyImageUploaded\tkeyName=" << keyNameForIndex(static_cast<int>(keyIndex)) << '\n';
    if (debug) {
      std::cout << "DEBUG=keyImageUploaded\tkeyName=" << keyNameForIndex(static_cast<int>(keyIndex))
                << "\tepochMs=" << epochMilliseconds() << "\tbyteCount=" << keyImage.size() << '\n';
    }
  }
  if (debug) {
    std::cout << "DEBUG=uploadKeyImagesFinished\tepochMs=" << epochMilliseconds() << '\n';
  }
  std::cout.flush();
}

} // namespace KaitoTokyo::LiveFunkeyDeck

auto main(int argc, char **argv) -> int {
  using namespace std::string_view_literals;
  using namespace KaitoTokyo::LiveFunkeyDeck;

  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);
  std::cout.tie(nullptr);
  std::cerr.tie(nullptr);

  std::string shortcutFolder = "live-funkey-deck";
  std::optional<std::string_view> serialNumber;
  bool debug = false;

  for (int i = 1; i < argc; i++) {
    ArgComponentView arg(argv[i]);
    if (arg.sv_ == "--") {
      if (i + 1 < argc) {
        std::cerr << "ERROR: No positional argument allowed.\n" LFD_USAGE "\n";
        return EX_USAGE;
      }
    } else if (arg.consumePrefix("--"sv)) {
      if (arg.sv_ == "help"sv) {
        std::cout << LFD_USAGE "\n\n" LFD_COPYRIGHT "\n";
        return EX_OK;
      } else if (arg.sv_ == "version"sv) {
        std::cout << "live-funkey-deck " LFD_VERSION "\n";
        return EX_OK;
      } else if (arg.sv_ == "licenses"sv) {
        std::cout << "<LICENSE>" << "</LICENSE>\n";
        return EX_OK;
      } else if (arg.sv_ == "debug"sv) {
        debug = true;
      } else if (arg.consumeLongOptionName("shortcut-folder"sv)) {
        if (auto consumed = arg.consumeValue(shortcutFolder, i + 1 < argc ? argv[i + 1] : nullptr)) {
          i += *consumed;
        } else {
          std::cerr << "ERROR: Missing value of --shortcut-folder.\n" LFD_USAGE "\n";
          return EX_USAGE;
        }
      } else if (arg.consumeLongOptionName("serial-number"sv)) {
        if (auto consumed = arg.consumeValue(serialNumber, i + 1 < argc ? argv[i + 1] : nullptr)) {
          i += *consumed;
        } else {
          std::cerr << "ERROR: Missing value of --serial-number.\n" LFD_USAGE "\n";
          return EX_USAGE;
        }
      } else {
        std::cerr << "ERROR: Unrecognized option(s) found.\n" LFD_USAGE "\n";
        return EX_USAGE;
      }
    } else {
      std::cerr << "ERROR: No positional argument allowed.\n" LFD_USAGE "\n";
      return EX_USAGE;
    }
  }

  std::cout << "INFO=argumentParsed\tidentifier=" LFD_IDENTIFIER "\tversion=" LFD_VERSION "\tshortcutFolder="
            << shortcutFolder << "\tserialNumber=" << serialNumber.value_or("(not specified)"sv)
            << "\tdebug=" << (debug ? "true" : "false") << '\n';
  std::cout.flush();

  auto elgatoVendorID = makeCFNumber(0x0FD9);
  auto streamDeckMk2ProductID = makeCFNumber(0x0080);

  auto streamDeckMk2Dict = makeCFDictionary(
      std::array<const void *, 2>{
          CFSTR(kIOHIDVendorIDKey),
          CFSTR(kIOHIDProductIDKey),
      },
      std::array<const void *, 2>{
          elgatoVendorID.get(),
          streamDeckMk2ProductID.get(),
      });

  auto multiple = makeCFArray(std::array<const void *, 1>{streamDeckMk2Dict.get()});

  UniqueIOHIDManagerPtr manager(IOHIDManagerCreate(nullptr, 0));
  if (!manager.get()) {
    std::cerr << "ERROR: IOHIDManager cannot be created.\n";
    return EX_OSERR;
  }

  IOHIDManagerSetDeviceMatchingMultiple(manager.get(), multiple.get());
  if (manager.open(0) != kIOReturnSuccess) {
    std::cerr << "ERROR: IOHIDManager cannot be opened.\n";
    return EX_OSERR;
  }

  std::unique_ptr<std::remove_pointer_t<CFSetRef>, decltype(&CFRelease)> matchedDeviceSet(
      IOHIDManagerCopyDevices(manager.get()), &CFRelease);
  if (!matchedDeviceSet) {
    std::cerr << "ERROR: No matched device found.\n";
    return EX_UNAVAILABLE;
  }

  struct DeviceSelector {
    void add(IOHIDDeviceRef device) {
      CFTypeRef vendorID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
      CFTypeRef productID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));

      if (CFEqual(vendorID, elgatoVendorID)) {
        if (CFEqual(productID, streamDeckMk2ProductID)) {
          selectedDevice = device;
          selectedDeviceModel.emplace<StreamDeckClassicModel>(15, std::array{72, 72}, M_PI);
        }
      }
    }

    IOHIDDeviceRef selectedDevice = nullptr;
    std::variant<std::monostate, StreamDeckClassicModel> selectedDeviceModel;
    const CFNumberRef elgatoVendorID;
    const CFNumberRef streamDeckMk2ProductID;
  } deviceSelector{
      .elgatoVendorID = elgatoVendorID.get(),
      .streamDeckMk2ProductID = streamDeckMk2ProductID.get(),
  };

  CFSetApplyFunction(
      matchedDeviceSet.get(),
      // NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
      [](const void *value, void *context) {
        static_cast<DeviceSelector *>(context)->add(static_cast<IOHIDDeviceRef>(const_cast<void *>(value)));
      },
      &deviceSelector);

  if (!deviceSelector.selectedDevice) {
    std::cerr << "ERROR: No device selected! Exiting...";
    return EX_UNAVAILABLE;
  }

  CFRunLoopRef runLoop = CFRunLoopGetCurrent();

  std::array exitSignals{SIGHUP, SIGINT, SIGTERM};
  for (auto &exitSignal : exitSignals) {
    signal(exitSignal, SIG_IGN);
  }

  std::array<dispatch_source_t, exitSignals.size()> exitSources;
  dispatch_queue_main_t mainQueue = dispatch_get_main_queue();
  for (std::size_t i = 0; i < exitSignals.size(); i++) {
    exitSources[i] = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, exitSignals[i], 0, mainQueue);
    dispatch_set_context(exitSources[i], runLoop);
    dispatch_source_set_event_handler_f(exitSources[i],
                                        [](void *context) { CFRunLoopStop(static_cast<CFRunLoopRef>(context)); });
  }

  if (auto deviceModel = std::get_if<StreamDeckClassicModel>(&deviceSelector.selectedDeviceModel)) {
    IOHIDDeviceRef device = deviceSelector.selectedDevice;
    std::vector<std::optional<std::string>> shortcutByKeyIndex(deviceModel->keyCount());
    ChildProcesses shortcutProcessIDs;
    bool acceptIconUpdates = true;

    for (const auto &shortcutName : listShortcutsInFolder(shortcutFolder.c_str())) {
      std::cout << "INFO=shortcutFound\tname=" << shortcutName << '\n';
      if (auto keyIndex = parseShortcutKeyIndex(shortcutName)) {
        if (static_cast<std::size_t>(*keyIndex) >= shortcutByKeyIndex.size()) {
          std::cerr << "WARNING: Shortcut key is out of range\tkeyName=" << keyNameForIndex(*keyIndex)
                    << "\tname=" << shortcutName << '\n';
        } else if (shortcutByKeyIndex[*keyIndex]) {
          std::cerr << "WARNING: Duplicate shortcut for keyName=" << keyNameForIndex(*keyIndex)
                    << "; keeping the first one.\n";
        } else {
          shortcutByKeyIndex[*keyIndex] = shortcutName;
          std::cout << "INFO=shortcutMapped\tkeyName=" << keyNameForIndex(*keyIndex) << "\tname=" << shortcutName
                    << '\n';
        }
      }
    }
    std::cout.flush();

    auto serialNumber = deviceModel->getUnitSerialNumber(device).value_or("(unknown)");
    std::cout << "INFO=deviceSelected\tdeviceModel=StreamDeckClassicModel\tserialNumber=" << serialNumber << '\n';
    std::cout.flush();

    auto applicationSupportDir = applicationSupportDirectory();
    if (!applicationSupportDir) {
      std::cerr << "ERROR: Failed to resolve Application Support directory.\n";
      return EX_OSERR;
    }

    auto shortcutIconsDir = *applicationSupportDir / LFD_IDENTIFIER / "shortcut-icons" / shortcutFolder;
    std::error_code error;
    std::filesystem::create_directories(shortcutIconsDir, error);
    auto keyCount = std::min<std::size_t>(deviceModel->keyCount(), defaultKeyImages().size());

    struct ExtractIconsContext {
      StreamDeckClassicModel *deviceModel;
      IOHIDDeviceRef device;
      const std::vector<std::optional<std::string>> *shortcutByKeyIndex;
      const std::filesystem::path *shortcutIconsDir;
      std::size_t keyCount;
      bool debug;
      bool *acceptIconUpdates;

      void uploadGeneratedKeyImages() const {
        uploadKeyImages(*deviceModel, device,
                        generateShortcutKeyImages(*shortcutByKeyIndex, *shortcutIconsDir, keyCount,
                                                  deviceModel->width(), deviceModel->height(), deviceModel->rotate(),
                                                  debug),
                        debug);
      }

    } extractIconsContext{
        .deviceModel = deviceModel,
        .device = device,
        .shortcutByKeyIndex = &shortcutByKeyIndex,
        .shortcutIconsDir = &shortcutIconsDir,
        .keyCount = keyCount,
        .debug = debug,
        .acceptIconUpdates = &acceptIconUpdates,
    };

    class ExtractIconsProcess : public ChildProcess {
    public:
      ExtractIconsProcess(pid_t pid, ExtractIconsContext &context) : ChildProcess(pid), context_(context) {}

      void onExit(int status) override {
        if (context_.debug) {
          std::cout << "DEBUG=extractShortcutIconsFinished\tepochMs=" << epochMilliseconds() << "\tstatus=" << status
                    << '\n';
        }

        if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
          std::cerr << "WARNING: Failed to invoke extract-icons shortcut.\n";
          return;
        }

        std::cout << "INFO=extractIconsInvoked\n";
        std::cout.flush();

        if (*context_.acceptIconUpdates) {
          context_.uploadGeneratedKeyImages();
        }
      }

    private:
      ExtractIconsContext &context_;
    };

    if (error) {
      std::cerr << "WARNING: Failed to create shortcut icons directory\tpath=" << shortcutIconsDir
                << "\terror=" << error.message() << '\n';
      uploadKeyImages(*deviceModel, device, {}, debug);
    } else if (shortcutIconsAvailable(shortcutByKeyIndex, shortcutIconsDir, deviceModel->keyCount(), debug)) {
      std::cout << "INFO=shortcutIconsReused\tpath=" << shortcutIconsDir << '\n';
      std::cout.flush();
      extractIconsContext.uploadGeneratedKeyImages();
    } else {
      uploadKeyImages(*deviceModel, device, {}, debug);
    }

    if (!error) {
      if (auto pid = startExtractShortcutIcons(shortcutIconsDir, debug)) {
        shortcutProcessIDs.push_back(std::make_unique<ExtractIconsProcess>(*pid, extractIconsContext));
      } else {
        std::cerr << "WARNING: Failed to invoke extract-icons shortcut.\n";
      }
    }

    struct HidReportCallbackContext {
      const StreamDeckClassicModel *deviceModel;
      const std::vector<std::optional<std::string>> &shortcutByKeyIndex;
      ChildProcesses &shortcutProcessIDs;
      std::set<StreamDeckClassicModel::KeyIndex> previousPressState;

      void handlePressStateChange(std::uint8_t *report, CFIndex reportLength) {
        auto pressState = deviceModel->parsePressStateChangeReport(report, reportLength);

        for (auto currentDownKeyIndex : pressState) {
          if (!previousPressState.contains(currentDownKeyIndex)) {
            std::cout << "INFO=keyDown\tkeyName=" << keyNameForIndex(currentDownKeyIndex) << '\n';
            handleKeyDown(currentDownKeyIndex);
          }
        }

        for (auto previousDownKeyIndex : previousPressState) {
          if (!pressState.contains(previousDownKeyIndex)) {
            std::cout << "INFO=keyUp\tkeyName=" << keyNameForIndex(previousDownKeyIndex) << '\n';
          }
        }

        previousPressState = pressState;
        std::cout.flush();
      }

      void handleKeyDown(StreamDeckClassicModel::KeyIndex keyIndex) {
        if (keyIndex >= shortcutByKeyIndex.size()) {
          return;
        }

        const auto &shortcut = shortcutByKeyIndex[keyIndex];
        if (!shortcut) {
          return;
        }

        if (auto pid = runShortcut(*shortcut)) {
          std::cout << "INFO=shortcutInvoked\tkeyName=" << keyNameForIndex(keyIndex) << "\tname=" << *shortcut
                    << "\tpid=" << *pid << '\n';
          shortcutProcessIDs.push_back(std::make_unique<ChildProcess>(*pid));
          return;
        }

        std::cerr << "ERROR: Failed to invoke shortcut\tkeyName=" << keyNameForIndex(keyIndex) << "\tname=" << *shortcut
                  << '\n';
      }
    } hidReportCallbackContext{
        .deviceModel = deviceModel,
        .shortcutByKeyIndex = shortcutByKeyIndex,
        .shortcutProcessIDs = shortcutProcessIDs,
    };

    auto hidReportCallback = [](void *context, IOReturn result, void *, IOHIDReportType type, std::uint32_t reportID,
                                std::uint8_t *report, CFIndex reportLength) -> void {
      if (auto callbackContext = static_cast<HidReportCallbackContext *>(context)) {
        if (result == kIOReturnSuccess && type == kIOHIDReportTypeInput && reportID == 0x01) {
          callbackContext->handlePressStateChange(report, reportLength);
        }
      }
    };

    std::array<std::uint8_t, 512> inputReport{};
    IOHIDDeviceRegisterInputReportCallback(device, inputReport.data(), inputReport.size(), hidReportCallback,
                                           &hidReportCallbackContext);

    IOHIDDeviceScheduleWithRunLoop(device, runLoop, kCFRunLoopDefaultMode);

    std::array exitSignals{SIGHUP, SIGINT, SIGTERM};
    for (auto &exitSignal : exitSignals) {
      signal(exitSignal, SIG_IGN);
    }

    for (auto &exitSource : exitSources) {
      dispatch_activate(exitSource);
    }

    while (true) {
      auto result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, false);
      reapFinishedChildProcesses(shortcutProcessIDs);
      if (result == kCFRunLoopRunStopped || result == kCFRunLoopRunFinished) {
        break;
      }
    }

    for (auto &exitSource : exitSources) {
      dispatch_source_cancel(exitSource);
    }

    acceptIconUpdates = false;

    IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, kCFRunLoopDefaultMode);

    if (deviceModel->showLogo(device) == kIOReturnSuccess) {
      std::cout << "INFO=resetDevice\n";
    } else {
      std::cerr << "WARNING: Failed to reset device";
    }

    waitForChildProcesses(shortcutProcessIDs, 0);

    return EX_OK;
  } else {
    std::cerr << "ERROR: No valid device found. Exiting...\n";
    return EX_UNAVAILABLE;
  }
}
