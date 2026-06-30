# SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
#
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.25)

set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS deployment version")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(LiveFunkeyDeck VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

add_executable(live-funkey-deck
    src/DeviceModel/StreamDeckClassicModel.cpp
    src/Resources/DefaultKeyImages.cpp
    src/Shortcuts/ShortcutIconGenerator.cpp
    src/live-funkey-deck.cpp
)

target_compile_options(live-funkey-deck PRIVATE
    -Wall
    -Wextra
    -Wpedantic
    -Wno-c23-extensions
)

target_link_libraries(live-funkey-deck PRIVATE
    "-framework CoreFoundation"
    "-framework CoreGraphics"
    "-framework ImageIO"
    "-framework IOKit"
)

install(TARGETS live-funkey-deck RUNTIME DESTINATION bin)
