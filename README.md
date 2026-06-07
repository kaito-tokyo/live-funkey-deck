<!--
SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>

SPDX-License-Identifier: Apache-2.0
-->

# Live Funkey Deck

Live Funkey Deck is a small commandline-based utility for streamer key devices that can be run on Terminal. It is designed to be integrated deeply with macOS itself and let users control everything. It only depends on macOS's built-in things such as USB HID drivers and Shortcuts.app. What this utility does is to connect to your streamer key device and run the Shortcut you added to your macOS. Since all works related to streaming is done by Shortcuts, you need to be familiar with Shortcuts.app instead of learning this utility.

## Installation

Prerequisites: Xcode

```
git clone https://github.com/kaito-tokyo/live-funkey-deck.git
cd live-funkey-deck
make
sudo make install
```

Install the shortcuts placed in [./Shortcuts](./Shortcuts) to your macOS. These are examples of how you can configure live-funkey-deck.

- **tokyo.kaito.live-funkey-deck.extract-icons**: This is a live-funkey-deck's system shortcut. Its name MUST NOT be changed but you can freely change its content if you understand how it works. This is needed to show your icons on the device.
- **F1 Scene Screenshot**: This is my example workflow to take a screenshot I use usually. The part of `F1` represents what key on your device triggers this shortcut. You can change the part of `Scene Screenshot`. The key and the name MUST be separated by a single space.

## Usage

Start Terminal on your macOS and run `live-funkey-deck`.

```zsh
umireon@umireon-macbook-pro live-funkey-deck % live-funkey-deck --help
live-funkey-deck: Small function key provider for Stream Deck
Usage: live-funkey-deck
  --shortcut-folder=NAME  Shortcut folder name to use. Default to live-funkey-deck.
  --serial-number=STRING  Serial number to select device. Optional when single device connected.
```

```zsh
umireon@umireon-macbook-pro live-funkey-deck % live-funkey-deck
Key Shortcut found: F1 Scene Screenshot
F1 down
F1 up
Invoked F1 Scene Screenshot
F2 down
F2 up
```
