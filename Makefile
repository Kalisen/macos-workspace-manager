APP = build/WorkspaceManager.app

INSTALLED = /Applications/WorkspaceManager.app

.PHONY: build test live-test run status app install

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

# Replaces the installed app and starts it. The ad-hoc signature changes with each build, so the
# previous permission grants are cleared and macOS asks again.
install: app
	-pkill -x WorkspaceManager
	-tccutil reset Accessibility io.github.kalisen.workspace-manager
	-tccutil reset ScreenCapture io.github.kalisen.workspace-manager
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	open $(INSTALLED)
