APP = build/WorkspaceManager.app

.PHONY: build test live-test run status app

build:
	swift build

test:
	swift test

# Moves a real TextEdit window: takes over the pointer and switches desktops for a few seconds.
live-test:
	WORKSPACE_MANAGER_LIVE=1 swift test --filter LiveMoveTests

# Runs from the terminal, using the terminal's Accessibility and Screen Recording permissions.
run: build
	.build/debug/WorkspaceManager

status: build
	.build/debug/WorkspaceManager --status

# Standalone app. Ad-hoc signed: macOS asks for the permissions again after each rebuild.
app:
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/WorkspaceManager $(APP)/Contents/MacOS/
	cp Support/Info.plist $(APP)/Contents/
	codesign --force --sign - $(APP)
