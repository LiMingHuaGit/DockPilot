.DEFAULT_GOAL := build
SHELL := /bin/bash

.PHONY: build run app install dmg notarize clean

## Compile the release binary
build:
	swift build -c release

## Run from the build tree (menu-bar app; quit from its menu)
run: app
	open build/DockPilot.app

## Assemble build/DockPilot.app (SIGN_IDENTITY env optional)
app:
	./scripts/build-app.sh

## Copy the app into /Applications
install: app
	rm -rf /Applications/DockPilot.app
	cp -R build/DockPilot.app /Applications/DockPilot.app
	@echo "Installed to /Applications/DockPilot.app"

## Package a drag-to-install DMG into build/
dmg: app
	./scripts/make-dmg.sh

## Notarize + staple (requires Developer ID signing; see scripts/notarize.sh)
notarize:
	./scripts/notarize.sh

## Remove build artifacts
clean:
	swift package clean
	rm -rf build
