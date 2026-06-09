<!--
SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>

SPDX-License-Identifier: Apache-2.0
-->

# Live Funkey Deck

Live Funkey Deck is a small command-line utility for streamer key devices. You can run it in Terminal on macOS. It integrates with macOS's Shortcuts.app seamlessly. The device can trigger user's own macOS Shortcuts as a simple launcher. Shortcuts.app is Apple's masterpiece to empower users by the visual programming, and this utility is designed to be a bridge between your device and it. I have attached some example workflows in [./Shortcuts](./Shortcuts). One is to control OBS via WebSocket.

## Installation

Prerequisites: Xcode

```
git clone https://github.com/kaito-tokyo/live-funkey-deck.git
cd live-funkey-deck
make
sudo make install
```

Install the shortcuts in [./Shortcuts](./Shortcuts) into the Shortcuts.app on macOS. These are examples of how you can configure live-funkey-deck. All shortcuts used by this utility MUST be installed under a folder named `live-funkey-deck`. You can change the folder name by `--shortcut-folder` option. This option is useful when you want profiles.

- **tokyo.kaito.live-funkey-deck.extract-icons**: This is a system shortcut used by live-funkey-deck. Its name MUST NOT be changed, but you can change its content if you understand how it works. This is needed to show your icons on the device.
- **F1 Scene Screenshot**: This is an example workflow to take a screenshot on OBS. The `F1` part indicates which key on your device triggers this shortcut. You can change `Scene Screenshot` freely. The key and the name MUST be separated by a single space.

## Usage

Open Terminal on macOS and run `live-funkey-deck`.

```zsh
umireon@umireon-macbook-pro live-funkey-deck % live-funkey-deck --help
live-funkey-deck 1.0.0: A small command-line utility for streamer key devices.
Usage: live-funkey-deck [--help] [--version] [options]
  --shortcut-folder=NAME  Shortcut folder name to use. Defaults to live-funkey-deck.
  --serial-number=STRING  Serial number to select device. Optional when a single device is connected.
  --licenses              Print licenses and exit.

Copyright 2026 Kaito Udagawa. Licensed under the Apache License, Version 2.0.
```

```zsh
umireon@umireon-macbook-pro live-funkey-deck % live-funkey-deck
event=argumentParsed	identifier=tokyo.kaito.live-funkey-deck	version=1.0.0	shortcutFolder=live-funkey-deck	serialNumber=(not specified)
event=deviceDetected	product=Stream Deck MK.2	serialNumber=000000000000
event=deviceSelected	product=Stream Deck MK.2	serialNumber=000000000000
event=extractIconsInvoked
event=keyDown	keyName=F1
event=keyUp	keyName=F1
^Cevent=resetDevice
```
