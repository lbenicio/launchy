# Makefile for building and distributing the Launchy macOS application
#
# APP_NAME and VERSION are read from Package.swift — edit them there.

# ── Read from Package.swift ─────────────────────────────────────────
APP_NAME      := $(shell grep 'let appName' Package.swift | sed 's/.*"\(.*\)".*/\1/')
VERSION       := $(shell grep 'let packageVersion' Package.swift | sed 's/.*"\(.*\)".*/\1/')

# ── Paths ───────────────────────────────────────────────────────────
BUILD_DIR     := .build
DIST_DIR      := .build/dist
RELEASE_BIN   := $(BUILD_DIR)/release/$(APP_NAME)

APP_BUNDLE    := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR  := $(APP_BUNDLE)/Contents
MACOS_DIR     := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

INFO_PLIST    := $(CONTENTS_DIR)/Info.plist
PLIST_TMPL    := assets/plists/Info.plist

ICON_SRC      := assets/icon/launchy.icns
ICON_DST      := $(RESOURCES_DIR)/launchy.icns

DMG_PATH      := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
DMG_BG        := assets/dmg/background.png
DMG_WRITABLE  := $(DIST_DIR)/$(APP_NAME)-rw.dmg

.DEFAULT_GOAL := bundle

.PHONY: help build debug bundle dmg fmt lint run test clean

# ── Help ────────────────────────────────────────────────────────────

help:
	@echo "Available targets:"
	@echo ""
	@echo "  Build"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  build       - Build the project in release configuration"
	@echo "  debug       - Build the project in debug configuration"
	@echo "  bundle      - Build release binary and assemble .app bundle"
	@echo ""
	@echo "  Distribution"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  dmg         - Create an unsigned compressed disk image"
	@echo ""
	@echo "  Development"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  run         - Run the application in debug mode"
	@echo "  test        - Execute the unit test suite"
	@echo "  fmt         - Format Swift sources using swift-format"
	@echo "  lint        - Lint Swift sources using swift-format"
	@echo "  clean       - Remove build artifacts and distribution outputs"
	@echo ""
	@echo "  APP_NAME    = $(APP_NAME)   (from Package.swift)"
	@echo "  VERSION     = $(VERSION)    (from Package.swift)"

# ── Build ───────────────────────────────────────────────────────────

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
	cp $(ICON_SRC) $(ICON_DST)
	sed \
		-e 's/{{APP_NAME}}/$(APP_NAME)/g' \
		-e 's/{{VERSION}}/$(VERSION)/g' \
		$(PLIST_TMPL) > $(INFO_PLIST)
	@echo "Creating PkgInfo..."
	@echo "APPL????" > $(CONTENTS_DIR)/PkgInfo
	@find $(APP_BUNDLE) -name '.DS_Store' -delete >/dev/null 2>&1 || true
	@echo "Bundle created at $(APP_BUNDLE)"

# ── Distribution (unsigned) ─────────────────────────────────────────

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
	-osascript scripts/dmg-setup.applescript "$(APP_NAME)-setup" "$(APP_NAME)" 2>/dev/null
	sync
	hdiutil detach "/Volumes/$(APP_NAME)-setup" || hdiutil detach "/Volumes/$(APP_NAME)-setup" -force
	hdiutil convert "$(DMG_WRITABLE)" -format UDZO -imagekey zlib-level=9 -o "$(DMG_PATH)"
	rm -f "$(DMG_WRITABLE)"
	@echo "DMG created at $(DMG_PATH)"

# ── Development ─────────────────────────────────────────────────────

fmt:
	swift format --in-place Package.swift src tests

lint:
	swift format --lint Package.swift src tests

run:
	swift run --configuration debug

test:
	swift test --parallel

clean:
	swift package clean
	rm -rf $(DIST_DIR)
