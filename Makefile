CONFIGURATION ?= release
PREFIX ?= /usr/local

PRODUCT := LiveFunkeyDeck
BUILT_PRODUCTS_DIR := .build/$(CONFIGURATION)
BUILD_STAMP := $(BUILT_PRODUCTS_DIR)/.make_build
CODESIGN_STAMP := $(BUILT_PRODUCTS_DIR)/.make_codesign

SWIFT_SOURCES := $(wildcard Sources/*/*.swift)
C_SOURCES := $(wildcard Sources/*/*.c)
C_HEADERS := $(wildcard Sources/*/*.h)
ASSET_SOURCES := $(wildcard Sources/LiveFunkeyDeckAssets/Resources/*)
PACKAGE_SOURCES := Package.swift

.PHONY: all build codesign install clean

all: codesign
build: $(BUILD_STAMP)
codesign: $(CODESIGN_STAMP)

$(BUILD_STAMP): $(SWIFT_SOURCES) $(C_SOURCES) $(C_HEADERS) $(ASSET_SOURCES) $(PACKAGE_SOURCES)
	swift build --configuration "$(CONFIGURATION)"
	touch "$(BUILD_STAMP)"

$(CODESIGN_STAMP): $(BUILD_STAMP)
	codesign --options runtime --sign - --force "$(BUILT_PRODUCTS_DIR)/$(PRODUCT)"
	touch "$(CODESIGN_STAMP)"

install: $(CODESIGN_STAMP)
	install -d "$(PREFIX)/bin"
	install -m755 "$(BUILT_PRODUCTS_DIR)/$(PRODUCT)" "$(PREFIX)/bin/$(PRODUCT)"

clean:
	rm -rf "$(BUILT_PRODUCTS_DIR)"
