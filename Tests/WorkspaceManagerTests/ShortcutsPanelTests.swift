import XCTest
@testable import WorkspaceManager

final class ShortcutsPanelTests: XCTestCase {
    func testListsTheConfiguredShortcuts() {
        var settings = Settings()
        settings.shortcuts.restoreWindows = "cmd+f5"
        let shortcuts = ShortcutsPanel.rows(for: settings).map(\.shortcut)
        XCTAssertEqual(Array(shortcuts.prefix(4)), ["⌃⌥Space", "⌃⌥⇧Space", "⌥⇧Right-click", "⌘F5"])
    }

    func testShowsDisabledAndInvalidShortcutsAsSuch() {
        var settings = Settings()
        settings.shortcuts.switchWorkspace = ""
        settings.shortcuts.sendWindow = "hyper+space"
        settings.titleBarMenu.modifiers = "meta"
        let shortcuts = ShortcutsPanel.rows(for: settings).map(\.shortcut)
        XCTAssertEqual(Array(shortcuts.prefix(3)), ["disabled", "invalid: hyper+space", "invalid: meta"])
    }
}
