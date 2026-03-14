# Makefile for building and distributing the Launchy macOS application

# Application settings
APP_NAME := Launchy
BUILD_DIR := .build
DIST_DIR := .build/dist
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
DMG_PATH     := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
DMG_BG       := assets/dmg/background.png
DMG_WRITABLE := $(DIST_DIR)/$(APP_NAME)-rw.dmg
PKG_PATH     := $(DIST_DIR)/$(APP_NAME)-$(VERSION).pkg
PKG_IDENTIFIER := dev.lbenicio.launchy.$(APP_NAME)

# Code signing & notarization settings.
# Set these via environment variables or a local .env file.
#   DEVELOPER_ID_APPLICATION  — "Developer ID Application: Your Name (TEAMID)"
#   DEVELOPER_ID_INSTALLER    — "Developer ID Installer: Your Name (TEAMID)"  (for signed .pkg)
#   APPLE_TEAM_ID             — 10-character Apple Developer Team ID
#   APPLE_ID                  — Apple ID email used with notarytool
#   APPLE_ID_PASSWORD         — App-specific password for notarytool
#   KEYCHAIN_PROFILE          — (alternative) notarytool stored keychain profile name
DEVELOPER_ID_APPLICATION ?=
DEVELOPER_ID_INSTALLER   ?=
APPLE_TEAM_ID            ?=
APPLE_ID                 ?=
APPLE_ID_PASSWORD        ?=
KEYCHAIN_PROFILE         ?=

# Temporary zip used during notarization upload
NOTARIZE_ZIP := $(DIST_DIR)/$(APP_NAME)-notarize.zip

.DEFAULT_GOAL := bundle

.PHONY: help build debug bundle sign notarize staple release dmg dmg-signed pkg pkg-signed fmt lint run test clean

help:
	@echo "Available targets:"
	@echo ""
	@echo "  Build"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  build       - Build the project in release configuration"
	@echo "  debug       - Build the project in debug configuration"
	@echo "  bundle      - Build release binary and assemble $(APP_NAME).app"
	@echo ""
	@echo "  Code Signing & Notarization"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  sign        - Code-sign the app bundle with hardened runtime"
	@echo "  notarize    - Submit the signed bundle to Apple for notarization"
	@echo "  staple      - Staple the notarization ticket to the app bundle"
	@echo "  release     - bundle → sign → notarize → staple → zip"
	@echo ""
	@echo "  Distribution"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  dmg         - Create a compressed disk image (unsigned)"
	@echo "  dmg-signed  - Create a signed & notarized disk image"
	@echo "  pkg         - Create an installer package (unsigned)"
	@echo "  pkg-signed  - Create a signed & notarized installer package"
	@echo ""
	@echo "  Development"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  run         - Run the application in debug mode"
	@echo "  test        - Execute the unit test suite"
	@echo "  fmt         - Format Swift sources using swift-format"
	@echo "  lint        - Lint Swift sources using swift-format"
	@echo "  clean       - Remove build artifacts and distribution outputs"
	@echo ""
	@echo "  Environment variables for signing/notarization:"
	@echo "    DEVELOPER_ID_APPLICATION  Signing identity for .app bundles"
	@echo "    DEVELOPER_ID_INSTALLER    Signing identity for .pkg installers"
	@echo "    APPLE_TEAM_ID             Apple Developer Team ID"
	@echo "    APPLE_ID                  Apple ID email for notarytool"
	@echo "    APPLE_ID_PASSWORD         App-specific password for notarytool"
	@echo "    KEYCHAIN_PROFILE          Alternative: notarytool keychain profile name"

# ───────────────────────────────────────────────────────────────────
# Build
# ───────────────────────────────────────────────────────────────────

build:
	swift build --configuration release

debug:
	swift build --configuration debug

bundle: build
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: Unable to determine packageVersion from Package.swift"; \
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

# ───────────────────────────────────────────────────────────────────
# Code Signing & Notarization
# ───────────────────────────────────────────────────────────────────

sign: bundle
	@if [ -z "$(DEVELOPER_ID_APPLICATION)" ]; then \
		echo "ERROR: DEVELOPER_ID_APPLICATION is not set."; \
		echo "  Export it before running, e.g.:"; \
		echo '  export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"'; \
		exit 1; \
	fi
	@echo "Signing $(APP_BUNDLE) …"
	codesign --deep --force --options runtime \
		--timestamp \
		--sign "$(DEVELOPER_ID_APPLICATION)" \
		$(APP_BUNDLE)
	@echo "Verifying signature …"
	codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)
	@echo "Signature OK"

notarize:
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "ERROR: $(APP_BUNDLE) does not exist. Run 'make sign' first."; \
		exit 1; \
	fi
	@echo "Preparing notarization archive …"
	rm -f $(NOTARIZE_ZIP)
	cd $(DIST_DIR) && zip -r -q $(notdir $(NOTARIZE_ZIP)) $(notdir $(APP_BUNDLE))
	@echo "Submitting to Apple notary service …"
	@if [ -n "$(KEYCHAIN_PROFILE)" ]; then \
		xcrun notarytool submit $(NOTARIZE_ZIP) \
			--keychain-profile "$(KEYCHAIN_PROFILE)" \
			--wait; \
	elif [ -n "$(APPLE_ID)" ] && [ -n "$(APPLE_ID_PASSWORD)" ] && [ -n "$(APPLE_TEAM_ID)" ]; then \
		xcrun notarytool submit $(NOTARIZE_ZIP) \
			--apple-id "$(APPLE_ID)" \
			--password "$(APPLE_ID_PASSWORD)" \
			--team-id "$(APPLE_TEAM_ID)" \
			--wait; \
	else \
		echo "ERROR: Notarization credentials not set."; \
		echo "  Either set KEYCHAIN_PROFILE (recommended), or all of:"; \
		echo "    APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID"; \
		rm -f $(NOTARIZE_ZIP); \
		exit 1; \
	fi
	rm -f $(NOTARIZE_ZIP)
	@echo "Notarization complete"

staple:
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "ERROR: $(APP_BUNDLE) does not exist."; \
		exit 1; \
	fi
	@echo "Stapling notarization ticket …"
	xcrun stapler staple $(APP_BUNDLE)
	@echo "Staple OK"

## release: full pipeline — build, sign, notarize, staple, and zip
release: sign notarize staple
	@echo "Creating release archive …"
	cd $(DIST_DIR) && rm -f $(APP_NAME)-$(VERSION).zip && \
		zip -r -q "$(APP_NAME)-$(VERSION).zip" "$(notdir $(APP_BUNDLE))"
	@echo "Release artifact: $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip"

# ───────────────────────────────────────────────────────────────────
# Distribution (unsigned)
# ───────────────────────────────────────────────────────────────────

# TODO: For a polished DMG, add a background image with an arrow pointing from
# the app icon to the /Applications symlink. This requires a .tiff or .png
# asset and an AppleScript to configure the Finder window appearance (icon
# size, background image, icon positions). For now we create a plain DMG with
# the Applications symlink so users can drag-to-install.
dmg: bundle
	@echo "Creating disk image at $(DMG_PATH)"
	rm -f "$(DMG_PATH)" "$(DMG_WRITABLE)"
	rm -rf "$(DIST_DIR)/dmg-stage"
	mkdir -p "$(DIST_DIR)/dmg-stage/.background"
	cp -R "$(APP_BUNDLE)" "$(DIST_DIR)/dmg-stage/"
	ln -s /Applications "$(DIST_DIR)/dmg-stage/Applications"
	@[ -f "$(DMG_BG)" ] && cp "$(DMG_BG)" "$(DIST_DIR)/dmg-stage/.background/background.png" && echo "  → embedding DMG background" || true
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DIST_DIR)/dmg-stage" -ov -format UDRW "$(DMG_WRITABLE)"
	rm -rf "$(DIST_DIR)/dmg-stage"
	hdiutil attach -nobrowse -noverify "$(DMG_WRITABLE)" -mountpoint "/Volumes/$(APP_NAME)-setup"
	@sleep 2
	-osascript scripts/dmg-setup.applescript 2>/dev/null
	sync
	hdiutil detach "/Volumes/$(APP_NAME)-setup" || hdiutil detach "/Volumes/$(APP_NAME)-setup" -force
	hdiutil convert "$(DMG_WRITABLE)" -format UDZO -imagekey zlib-level=9 -o "$(DMG_PATH)"
	rm -f "$(DMG_WRITABLE)"
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

# ───────────────────────────────────────────────────────────────────
# Distribution (signed & notarized)
# ───────────────────────────────────────────────────────────────────

dmg-signed: sign notarize staple
	@echo "Creating signed disk image at $(DMG_PATH)"
	rm -f "$(DMG_PATH)" "$(DMG_WRITABLE)"
	rm -rf "$(DIST_DIR)/dmg-stage"
	mkdir -p "$(DIST_DIR)/dmg-stage/.background"
	cp -R "$(APP_BUNDLE)" "$(DIST_DIR)/dmg-stage/"
	ln -s /Applications "$(DIST_DIR)/dmg-stage/Applications"
	@[ -f "$(DMG_BG)" ] && cp "$(DMG_BG)" "$(DIST_DIR)/dmg-stage/.background/background.png" && echo "  → embedding DMG background" || true
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DIST_DIR)/dmg-stage" -ov -format UDRW "$(DMG_WRITABLE)"
	rm -rf "$(DIST_DIR)/dmg-stage"
	hdiutil attach -nobrowse -noverify "$(DMG_WRITABLE)" -mountpoint "/Volumes/$(APP_NAME)-setup"
	@sleep 2
	-osascript scripts/dmg-setup.applescript 2>/dev/null
	sync
	hdiutil detach "/Volumes/$(APP_NAME)-setup" || hdiutil detach "/Volumes/$(APP_NAME)-setup" -force
	hdiutil convert "$(DMG_WRITABLE)" -format UDZO -imagekey zlib-level=9 -o "$(DMG_PATH)"
	rm -f "$(DMG_WRITABLE)"
	@# Sign the DMG itself
	codesign --force --sign "$(DEVELOPER_ID_APPLICATION)" --timestamp "$(DMG_PATH)"
	@# Notarize and staple the DMG
	@echo "Submitting DMG to Apple notary service …"
	@if [ -n "$(KEYCHAIN_PROFILE)" ]; then \
		xcrun notarytool submit "$(DMG_PATH)" \
			--keychain-profile "$(KEYCHAIN_PROFILE)" \
			--wait; \
	else \
		xcrun notarytool submit "$(DMG_PATH)" \
			--apple-id "$(APPLE_ID)" \
			--password "$(APPLE_ID_PASSWORD)" \
			--team-id "$(APPLE_TEAM_ID)" \
			--wait; \
	fi
	xcrun stapler staple "$(DMG_PATH)"
	@echo "Signed DMG created at $(DMG_PATH)"

pkg-signed: sign notarize staple
	@if [ -z "$(DEVELOPER_ID_INSTALLER)" ]; then \
		echo "ERROR: DEVELOPER_ID_INSTALLER is not set."; \
		echo '  export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"'; \
		exit 1; \
	fi
	@echo "Creating signed installer package at $(PKG_PATH)"
	rm -f $(PKG_PATH)
	pkgbuild \
		--component "$(APP_BUNDLE)" \
		--install-location "/Applications" \
		--identifier "$(PKG_IDENTIFIER)" \
		--version "$(VERSION)" \
		--sign "$(DEVELOPER_ID_INSTALLER)" \
		--timestamp \
		"$(PKG_PATH)"
	@# Notarize and staple the PKG
	@echo "Submitting PKG to Apple notary service …"
	@if [ -n "$(KEYCHAIN_PROFILE)" ]; then \
		xcrun notarytool submit $(PKG_PATH) \
			--keychain-profile "$(KEYCHAIN_PROFILE)" \
			--wait; \
	else \
		xcrun notarytool submit $(PKG_PATH) \
			--apple-id "$(APPLE_ID)" \
			--password "$(APPLE_ID_PASSWORD)" \
			--team-id "$(APPLE_TEAM_ID)" \
			--wait; \
	fi
	xcrun stapler staple $(PKG_PATH)
	@echo "Signed PKG created at $(PKG_PATH)"

# ───────────────────────────────────────────────────────────────────
# Development
# ───────────────────────────────────────────────────────────────────

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
