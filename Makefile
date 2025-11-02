###
# Launchy Makefile
# Production-oriented workflows for building, testing, linting, and releasing the Launchy app.
# Tasks assume macOS with Xcode command-line tools and Homebrew available where needed.
###

# Configurable variables
BUNDLE_ID           ?= dev.lbenicio.launchy
PACKAGE             ?= Launchy
CONFIG              ?= Release
BUILD_DIR           ?= .build

ARCHS               ?= "arm64"

SCHEME              ?= ${PACKAGE}
DIST_DIR            ?= ${BUILD_DIR}/dist
CONFIG_LOWER        := $(shell echo $(CONFIG) | tr '[:upper:]' '[:lower:]')
BIN_PATH             = $(BUILD_DIR)/$(CONFIG_LOWER)/$(PACKAGE)
APP_BUNDLE          := $(DIST_DIR)/$(PACKAGE).app
APP_CONTENTS        := $(APP_BUNDLE)/Contents
APP_MACOS           := $(APP_CONTENTS)/MacOS
APP_RESOURCES       := $(APP_CONTENTS)/Resources
INFOPLIST_TEMPLATE  ?= assets/plist/Info.plist.template
APP_ICON            ?= assets/icon/launchy.icns

SWIFT               := swift
SWIFTFORMAT         ?= swiftformat
SWIFTLINT           ?= swiftlint
XCODEBUILD          := xcodebuild
PLISTBUDDY          := /usr/libexec/PlistBuddy
PKGROOT             := $(shell pwd)
ARCHIVE_PATH        := $(BUILD_DIR)/archives/$(PACKAGE).xcarchive
PKG_PATH            := $(DIST_DIR)/$(PACKAGE).pkg
DMG_PATH            := $(DIST_DIR)/$(PACKAGE).dmg

# Default target
.DEFAULT_GOAL := bundle

# Convenience helper; make sure directories exist before writing artifacts
MKDIR_P = mkdir -p

# Version: prefer explicit VERSION, else parse from Package.swift (let packageVersion = "x.y.z"),
# else fall back to git describe, else 0.1.0
BUNDLE_VERSION ?= $(shell bash -c 'if [ -n "$(VERSION)" ]; then echo "$(VERSION)"; else v=$$(awk -F "\"" '\''/(let|static[[:space:]]+let)[[:space:]]+packageVersion[[:space:]]*=/{print $$2; exit}'\'' Package.swift 2>/dev/null); if [ -z "$$v" ]; then v=$$(git describe --tags --always --dirty 2>/dev/null || echo 0.1.0); fi; echo "$$v"; fi')

# Build number defaults to a numeric form of the bundle version; override with BUNDLE_BUILD if needed
BUNDLE_BUILD ?= $(shell bash -c 'ver="$(BUNDLE_VERSION)"; cleaned=$$(echo "$$ver" | sed -E "s/[^0-9]+/./g" | sed -E "s/^\.+//; s/\.+$$//" | sed -E "s/\.{2,}/./g"); if [ -z "$$cleaned" ]; then cleaned=0; fi; echo "$$cleaned"')

.PHONY: help
help:
	@echo "Launchy build targets"
	@echo "  make build         # Debug build via swift build"
	@echo "  make release       # Release build into $(BUILD_DIR)/$(CONFIG_LOWER)"
	@echo "  make bundle        # Assemble $(PACKAGE).app in $(APP_BUNDLE)"
	@echo "  make run           # Run debug binary"
	@echo "  make test          # Execute unit tests"
	@echo "  make format        # Format code with swiftformat"
	@echo "  make lint          # Run swiftlint if available"
	@echo "  make clean         # Remove build artifacts"
	@echo "  make archive       # Create signed xcarchive"
	@echo "  make pkg           # Build signed installer package"
	@echo "  make dmg           # Create distributable dmg"
	@echo "  make deploy        # Merge release branch into production via scripts/deploy"

.PHONY: build
build:
	$(SWIFT) build

.PHONY: release
release:
	$(SWIFT) build -c $(CONFIG_LOWER)
	@echo "Release binary available at $(BIN_PATH)"

.PHONY: bundle
bundle: release
	@if [ ! -f "$(BIN_PATH)" ]; then \
		echo "Release binary not found at $(BIN_PATH)."; \
		echo "Run 'make release' to build it."; \
		exit 1; \
	fi
	$(MKDIR_P) "$(APP_MACOS)" "$(APP_RESOURCES)"
	cp "$(BIN_PATH)" "$(APP_MACOS)/$(PACKAGE)"
	chmod +x "$(APP_MACOS)/$(PACKAGE)"
	@if [ -f "$(INFOPLIST_TEMPLATE)" ]; then \
		sed \
			-e "s/__BUNDLE_EXECUTABLE__/$(PACKAGE)/" \
			-e "s/__BUNDLE_IDENTIFIER__/$(BUNDLE_ID)/" \
			-e "s/__BUNDLE_NAME__/$(PACKAGE)/" \
			-e "s/__BUNDLE_VERSION__/$(BUNDLE_VERSION)/" \
			-e "s/__BUNDLE_BUILD__/$(BUNDLE_BUILD)/" \
			"$(INFOPLIST_TEMPLATE)" > "$(APP_CONTENTS)/Info.plist"; \
	else \
		echo "Info.plist template not found at $(INFOPLIST_TEMPLATE)"; \
		exit 1; \
	fi
	@if [ -f "$(APP_ICON)" ]; then \
		cp "$(APP_ICON)" "$(APP_RESOURCES)/AppIcon.icns"; \
		touch "$(APP_RESOURCES)/AppIcon.icns"; \
	fi
	@echo "Assembled app bundle at $(APP_BUNDLE)"

.PHONY: run
run:
	$(SWIFT) run

.PHONY: test
test:
	$(SWIFT) test

.PHONY: format
format:
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		$(SWIFTFORMAT) src --quiet; \
	else \
		echo "swiftformat not installed. Install via 'brew install swiftformat'"; \
	fi

.PHONY: lint
lint:
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) --fix; \
	else \
		echo "swiftlint not installed. Install via 'brew install swiftlint'"; \
	fi

.PHONY: clean
clean:
	rm -rf $(DIST_DIR) $(BUILD_DIR)

.PHONY: deploy
deploy:
	./scripts/update_changelog.sh
	./scripts/deploy.sh $(DEPLOY_ARGS)

# ----- Distribution-oriented targets below this line -----

.PHONY: archive
archive: clean
	$(MKDIR_P) $(dir $(ARCHIVE_PATH))
	$(XCODEBUILD) archive \
		-project $(SCHEME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-archivePath $(ARCHIVE_PATH) \
		skipInstall=NO \
		buildLibraryForDistribution=YES

.PHONY: pkg
pkg: archive
	$(MKDIR_P) $(dir $(PKG_PATH))
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist assets/plist/exportOptions.plist \
		-exportPath $(dir $(PKG_PATH))

.PHONY: dmg
dmg: bundle
	$(MKDIR_P) $(dir $(DMG_PATH))
	rm -f "$(DMG_PATH)"
	hdiutil create -volname "$(PACKAGE)" -srcfolder "$(APP_BUNDLE)" "$(DMG_PATH)"

# Utility target to print the current version from Info.plist
.PHONY: version
version:
	@echo "$(BUNDLE_VERSION)"
