# Makefile for building and distributing the Launchy macOS application

# Application settings
APP_NAME := Launchy
BUILD_DIR := .build
DIST_DIR := dist
RELEASE_BIN := $(BUILD_DIR)/release/$(APP_NAME)
DEBUG_BIN := $(BUILD_DIR)/debug/$(APP_NAME)
VERSION := $(shell sed -n 's/^let packageVersion = "\(.*\)"/\1/p' Package.swift)

# Define paths for the app bundle structure
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

# Info.plist paths
INFO_PLIST := $(CONTENTS_DIR)/Info.plist
PLIST_TEMPLATE := assets/plists/Info.plist

# Icon paths
ICON_SOURCE := assets/icon/launchy.icns
ICON_DEST := $(RESOURCES_DIR)/launchy.icns

# Distribution artifact paths
DMG_PATH := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
PKG_PATH := $(DIST_DIR)/$(APP_NAME)-$(VERSION).pkg
PKG_IDENTIFIER := dev.lbenicio.launchy.$(APP_NAME)

.DEFAULT_GOAL := bundle

.PHONY: help build debug bundle dmg pkg fmt lint run test clean

help:
	@echo "Available targets:"
	@echo "  bundle  - Build the release binary and assemble $(APP_NAME).app"
	@echo "  dmg     - Create a compressed disk image from the app bundle"
	@echo "  pkg     - Create an installer package from the app bundle"
	@echo "  build   - Build the project in release configuration"
	@echo "  debug   - Build the project in debug configuration"
	@echo "  run     - Run the application in debug mode"
	@echo "  test    - Execute the unit test suite"
	@echo "  fmt     - Format the Swift sources using swift-format"
	@echo "  lint    - Lint the Swift sources using swift-format"
	@echo "  clean   - Remove build artifacts and distribution outputs"

build:
	swift build --configuration release

debug:
	swift build --configuration debug

bundle: build
	@if [ -z "$(VERSION)" ]; then \
		echo "Unable to determine packageVersion from Package.swift"; \
		exit 1; \
	fi
	@echo "Assembling $(APP_NAME).app (version $(VERSION))"
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(RELEASE_BIN) $(MACOS_DIR)/$(APP_NAME)
	chmod +x $(MACOS_DIR)/$(APP_NAME)
	cp $(ICON_SOURCE) $(ICON_DEST)
	sed \
		-e 's/{{APP_NAME}}/$(APP_NAME)/g' \
		-e 's/{{VERSION}}/$(VERSION)/g' \
		$(PLIST_TEMPLATE) > $(INFO_PLIST)
	@find $(APP_BUNDLE) -name '.DS_Store' -delete >/dev/null 2>&1 || true
	@echo "Bundle created at $(APP_BUNDLE)"

dmg: bundle
	@echo "Creating disk image at $(DMG_PATH)"
	rm -f $(DMG_PATH)
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(APP_BUNDLE)" -ov -format UDZO "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"

pkg: bundle
	@echo "Creating installer package at $(PKG_PATH)"
	rm -f $(PKG_PATH)
	pkgbuild \
		--component "$(APP_BUNDLE)" \
		--install-location "/Applications" \
		--identifier "$(PKG_IDENTIFIER)" \
		--version "$(VERSION)" \
		"$(PKG_PATH)"
	@echo "PKG created at $(PKG_PATH)"

fmt:
	swift format --in-place Package.swift src tests

lint:
	swift format --lint Package.swift src tests

run:
	swift run --configuration debug

test:
	swift test

clean:
	swift package clean
	rm -rf $(DIST_DIR)
