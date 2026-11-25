# Development commands for Kaštan for macOS.

SWIFT ?= swift
XCODEBUILD ?= xcodebuild
GIT ?= git
HDIUTIL ?= hdiutil
DITTO ?= ditto
LIPO ?= lipo
CODESIGN ?= codesign
UNZIP ?= unzip
LSREGISTER ?= /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
KILLALL ?= killall
MDFIND ?= mdfind
OSASCRIPT ?= osascript

APP_PROJECT := KastanApp/KastanApp.xcodeproj
APP_SCHEME := KastanApp
APP_DESTINATION := platform=macOS
# Spotlight de-duplicates the ASCII bundle filename while localization preserves the Kaštan product name.
APP_BUNDLE_NAME := Kaštan
APP_BUNDLE_FILENAME := Kastan
APP_BUNDLE_IDENTIFIER := cz.glutexo.kastan
APP_ENTITLEMENTS := KastanApp/KastanApp.entitlements
APP_VERSION := $(shell sed -n 's/^[[:space:]]*MARKETING_VERSION = \([^;]*\);/\1/p' $(APP_PROJECT)/project.pbxproj | head -n 1)
APP_BUILD_DIR := .build/macos-app.noindex
APP_BUILD_PRODUCT := $(APP_BUILD_DIR)/Build/Products/Debug/$(APP_BUNDLE_FILENAME).app
APP_INSTALL_DIR ?= $(HOME)/Applications
APP_INSTALL_BUILD_DIR := .build/install-app.noindex
APP_INSTALL_SOURCE := $(APP_INSTALL_BUILD_DIR)/Build/Products/Debug/$(APP_BUNDLE_FILENAME).app
APP_INSTALL_PATH := $(APP_INSTALL_DIR)/$(APP_BUNDLE_FILENAME).app
APP_LEGACY_INSTALL_PATH := $(APP_INSTALL_DIR)/$(APP_BUNDLE_NAME).app

DIST_DIR ?= dist
DIST_BUILD_DIR := .build/distribution.noindex
DIST_APP := $(DIST_BUILD_DIR)/Build/Products/Release/$(APP_BUNDLE_FILENAME).app
DMG_ROOT := $(DIST_BUILD_DIR)/dmg-root
DMG_PATH := $(DIST_DIR)/kastan-$(APP_VERSION)-macos.dmg
SOURCE_ZIP_PATH := $(DIST_DIR)/kastan-$(APP_VERSION)-source.zip

.DEFAULT_GOAL := dist

.PHONY: help build install-app test test-app test-tooling dist dmg source-zip check-dist

help:
	@printf '%s\n' \
		'  make               Create the macOS DMG and source ZIP.' \
		'  make build         Build the macOS app.' \
		'  make install-app   Build and install the Spotlight-visible app.' \
		'  make test          Run app and tooling tests.' \
		'  make test-app      Run the app tests.' \
		'  make test-tooling  Run the tooling tests.' \
		'  make dmg           Create a universal macOS DMG.' \
		'  make source-zip    Archive the buildable sources from Git HEAD.'

build: ## Build the macOS app.
	LSREGISTER="$(LSREGISTER)" sh Scripts/run-xcodebuild-without-spotlight.sh \
		"$(abspath $(APP_BUILD_PRODUCT))" "$(XCODEBUILD)" build \
		-project $(APP_PROJECT) \
		-scheme $(APP_SCHEME) \
		-destination '$(APP_DESTINATION)' \
		-onlyUsePackageVersionsFromResolvedFile \
		-derivedDataPath "$(APP_BUILD_DIR)" \
		CODE_SIGNING_ALLOWED=NO

install-app: ## Build, install, and de-duplicate the macOS app for Spotlight.
	LSREGISTER="$(LSREGISTER)" sh Scripts/run-xcodebuild-without-spotlight.sh \
		"$(abspath $(APP_INSTALL_SOURCE))" "$(XCODEBUILD)" build \
		-project $(APP_PROJECT) \
		-scheme $(APP_SCHEME) \
		-configuration Debug \
		-destination '$(APP_DESTINATION)' \
		-onlyUsePackageVersionsFromResolvedFile \
		-derivedDataPath "$(APP_INSTALL_BUILD_DIR)" \
		CODE_SIGN_IDENTITY=- \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGNING_ALLOWED=YES
	$(CODESIGN) --verify --deep --strict "$(APP_INSTALL_SOURCE)"
	@LSREGISTER="$(LSREGISTER)" sh Scripts/keep-current-app-registered.sh \
		"$(APP_BUNDLE_IDENTIFIER)" "$(abspath $(APP_INSTALL_SOURCE))"
	@DITTO="$(DITTO)" KILLALL="$(KILLALL)" LSREGISTER="$(LSREGISTER)" \
		MDFIND="$(MDFIND)" OSASCRIPT="$(OSASCRIPT)" \
		sh Scripts/install-app-for-spotlight.sh \
			"$(APP_BUNDLE_IDENTIFIER)" "$(abspath $(APP_INSTALL_SOURCE))" \
			"$(abspath $(APP_INSTALL_PATH))" "$(abspath $(APP_LEGACY_INSTALL_PATH))"
	@LSREGISTER="$(LSREGISTER)" sh Scripts/keep-current-app-registered.sh \
		"$(APP_BUNDLE_IDENTIFIER)" "$(abspath $(APP_INSTALL_PATH))"
	@$(KILLALL) Spotlight >/dev/null 2>&1 || true
	@printf 'Installed %s\n' "$(APP_INSTALL_PATH)"

test: test-app test-tooling ## Run app and tooling tests.

test-app: ## Test the macOS app.
	LSREGISTER="$(LSREGISTER)" sh Scripts/run-xcodebuild-without-spotlight.sh \
		"$(abspath $(APP_BUILD_PRODUCT))" "$(XCODEBUILD)" test \
		-project $(APP_PROJECT) \
		-scheme $(APP_SCHEME) \
		-destination '$(APP_DESTINATION)' \
		-onlyUsePackageVersionsFromResolvedFile \
		-derivedDataPath "$(APP_BUILD_DIR)" \
		CODE_SIGNING_ALLOWED=NO

test-tooling: ## Test repository development tooling.
	sh Scripts/Tests/macos-app-name-tests.sh
	sh Scripts/Tests/macos-app-build-path-tests.sh
	$(SWIFT) Scripts/Tests/macos-app-icon-tests.swift
	sh Scripts/Tests/install-app-for-spotlight-tests.sh
	sh Scripts/Tests/keep-current-app-registered-tests.sh
	sh Scripts/Tests/run-xcodebuild-without-spotlight-tests.sh

dist: check-dist ## Create every downloadable archive from a clean Git HEAD.
	$(MAKE) dmg
	$(MAKE) source-zip

check-dist:
	@if test -n "$$($(GIT) status --porcelain)"; then \
		printf '%s\n' 'Cannot create matching distribution archives from a dirty Git worktree.' >&2; \
		exit 1; \
	fi

dmg: ## Create an ad-hoc-signed universal macOS DMG.
	mkdir -p "$(DIST_DIR)"
	LSREGISTER="$(LSREGISTER)" sh Scripts/run-xcodebuild-without-spotlight.sh \
		"$(abspath $(DIST_APP))" "$(XCODEBUILD)" build \
		-project $(APP_PROJECT) \
		-scheme $(APP_SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-onlyUsePackageVersionsFromResolvedFile \
		-derivedDataPath "$(DIST_BUILD_DIR)" \
		ARCHS='arm64 x86_64' \
		ONLY_ACTIVE_ARCH=NO \
		CODE_SIGN_IDENTITY=- \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGNING_ALLOWED=YES
	$(CODESIGN) \
		--force \
		--sign - \
		--options runtime \
		--timestamp=none \
		--entitlements "$(APP_ENTITLEMENTS)" \
		"$(DIST_APP)"
	$(LIPO) "$(DIST_APP)/Contents/MacOS/KastanApp" -verify_arch arm64
	$(LIPO) "$(DIST_APP)/Contents/MacOS/KastanApp" -verify_arch x86_64
	$(CODESIGN) --verify --deep --strict "$(DIST_APP)"
	rm -rf "$(DMG_ROOT)"
	mkdir -p "$(DMG_ROOT)"
	$(DITTO) "$(DIST_APP)" "$(DMG_ROOT)/$(APP_BUNDLE_FILENAME).app"
	ln -s /Applications "$(DMG_ROOT)/Applications"
	rm -f "$(DMG_PATH)"
	$(HDIUTIL) create \
		-volname "$(APP_BUNDLE_NAME) $(APP_VERSION)" \
		-srcfolder "$(DMG_ROOT)" \
		-format UDZO \
		"$(DMG_PATH)"
	$(HDIUTIL) verify "$(DMG_PATH)"
	@printf 'Created %s\n' "$(DMG_PATH)"

source-zip: ## Archive the buildable sources from Git HEAD.
	mkdir -p "$(DIST_DIR)"
	rm -f "$(SOURCE_ZIP_PATH)"
	$(GIT) archive \
		--format=zip \
		--prefix="kastan-$(APP_VERSION)/" \
		--output="$(SOURCE_ZIP_PATH)" \
		HEAD
	$(UNZIP) -tq "$(SOURCE_ZIP_PATH)"
	@printf 'Created %s\n' "$(SOURCE_ZIP_PATH)"
