import XCTest
@testable import MacDesktop

final class MissionControlShortcutsTests: XCTestCase {
    private func entry(enabled: Bool, keyCode: Int = 0, flags: Int = 0) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [65535, keyCode, flags], "type": "standard"]]
    }

    func testUntouchedPreferencesMeanControlArrowsOnAndDesktopShortcutsOff() {
        let shortcuts = MissionControlShortcuts(stored: [:])
        XCTAssertEqual(shortcuts.left?.keyCode, 123)
        XCTAssertEqual(shortcuts.right?.keyCode, 124)
        XCTAssertEqual(shortcuts.left?.flags.contains(.maskControl), true)
        XCTAssertTrue(shortcuts.desktop.isEmpty)
    }

    func testDisabledShortcutIsAbsent() {
        let shortcuts = MissionControlShortcuts(stored: ["79": entry(enabled: false, keyCode: 123), "120": entry(enabled: false, keyCode: 20)])
        XCTAssertNil(shortcuts.left)
        XCTAssertNotNil(shortcuts.right)
        XCTAssertNil(shortcuts.desktop[3])
    }

    func testCustomKeysAreUsed() {
        let shortcuts = MissionControlShortcuts(stored: [
            "81": entry(enabled: true, keyCode: 38, flags: Int(CGEventFlags.maskCommand.rawValue)),
            "120": entry(enabled: true, keyCode: 20, flags: Int(CGEventFlags.maskControl.rawValue)),
        ])
        XCTAssertEqual(shortcuts.right, SystemShortcut(keyCode: 38, flags: .maskCommand))
        XCTAssertEqual(shortcuts.desktop, [3: SystemShortcut(keyCode: 20, flags: .maskControl)])
    }
}
