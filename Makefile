APP_NAME := TahoeLaunchpad
BUILD_DIR := .build
BIN_PATH := $(BUILD_DIR)/debug/$(APP_NAME)
VERSION := $(shell sed -n 's/^let packageVersion = "\(.*\)"/\1/p' Package.swift)
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
INFO_PLIST := $(CONTENTS_DIR)/Info.plist
PLIST_TEMPLATE := assets/plists/Info.plist

.PHONY: all build clean bundle

all: build

build:
	swift build --configuration debug

clean:
	swift package clean
	rm -rf $(DIST_DIR)

bundle: build
	@if [ -z "$(VERSION)" ]; then \
		echo "Unable to determine packageVersion from Package.swift"; \
		exit 1; \
	fi
	@echo "Assembling $(APP_NAME).app (version $(VERSION))"
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(BIN_PATH) $(MACOS_DIR)/$(APP_NAME)
	chmod +x $(MACOS_DIR)/$(APP_NAME)
	sed \
		-e 's/{{APP_NAME}}/$(APP_NAME)/g' \
		-e 's/{{VERSION}}/$(VERSION)/g' \
		$(PLIST_TEMPLATE) > $(INFO_PLIST)
	@echo "Bundle created at $(APP_BUNDLE)"
