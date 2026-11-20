import XCTest
@testable import MacDesktop

final class KeyStrokeTests: XCTestCase {
    func testParsesModifiersAndKey() {
        XCTAssertEqual(KeyStroke("ctrl+alt+space"), KeyStroke(keyCode: 49, modifiers: [.control, .option]))
        XCTAssertEqual(KeyStroke("Cmd + Shift + R"), KeyStroke(keyCode: 15, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyStroke("f5"), KeyStroke(keyCode: 96, modifiers: []))
    }

    func testRejectsUnknownKeysAndModifiers() {
        XCTAssertNil(KeyStroke("ctrl+alt"))
        XCTAssertNil(KeyStroke("hyper+space"))
        XCTAssertNil(KeyStroke(""))
    }

    func testParsesModifierSets() {
        XCTAssertEqual(KeyStroke.Modifiers("alt+shift"), [.option, .shift])
        XCTAssertEqual(KeyStroke.Modifiers(""), [])
        XCTAssertNil(KeyStroke.Modifiers("alt+space"))
    }

    func testReadsModifiersFromEventFlagsIgnoringOthers() {
        XCTAssertEqual(KeyStroke.Modifiers([.maskAlternate, .maskShift, .maskSecondaryFn, .maskAlphaShift]), [.option, .shift])
    }

    func testDisplaysShortcutsWithMacGlyphs() {
        XCTAssertEqual(KeyStroke("ctrl+alt+shift+space")?.symbols, "⌃⌥⇧Space")
        XCTAssertEqual(KeyStroke("cmd+r")?.symbols, "⌘R")
        XCTAssertEqual(KeyStroke("ctrl+left")?.symbols, "⌃←")
        XCTAssertEqual(KeyStroke("f5")?.symbols, "F5")
        XCTAssertEqual(KeyStroke.Modifiers("alt+shift")?.symbols, "⌥⇧")
    }
}
