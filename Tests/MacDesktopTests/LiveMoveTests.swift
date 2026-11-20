import AppKit
import Workspaces
import XCTest
@testable import MacDesktop

/// Moves a real TextEdit window between desktops. Takes over the pointer and switches desktops,
/// so it only runs on request: `WORKSPACE_MANAGER_LIVE=1 swift test --filter LiveMoveTests`.
final class LiveMoveTests: XCTestCase {
    private var document: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WORKSPACE_MANAGER_LIVE"] == "1", "live desktop test not requested")
        try XCTSkipUnless(AXIsProcessTrusted(), "Accessibility permission missing")
        document = FileManager.default.temporaryDirectory.appendingPathComponent("workspace-manager-live-\(UUID().uuidString).txt")
        try "live move test".write(to: document, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.apple.TextEdit" }.forEach { $0.terminate() }
        if let document { try? FileManager.default.removeItem(at: document) }
    }

    func testWindowMovesToAnotherDesktopAndBack() throws {
        XCTAssertFalse(NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.TextEdit" },
                       "quit TextEdit first: the test closes it")
        let opened = expectation(description: "TextEdit opened")
        NSWorkspace.shared.open([document], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                                configuration: NSWorkspace.OpenConfiguration()) { _, _ in opened.fulfill() }
        wait(for: [opened], timeout: 10)

        var window: LiveWindow?
        XCTAssertTrue(SyntheticInput.wait(upTo: 5, every: 0.2) {
            guard let layout = try? SpaceReader.layout() else { return false }
            window = WindowReader.windows(in: layout).first { $0.bundleID == "com.apple.TextEdit" }
            return window != nil
        }, "TextEdit window not found")
        let subject = try XCTUnwrap(window)

        let layout = try SpaceReader.layout()
        let display = try XCTUnwrap(layout.display(ofSpace: subject.spaceID))
        let others = display.desktops.filter { !$0.isFullscreen && $0.spaceID != subject.spaceID }
        let near = try XCTUnwrap(others.min { abs(layout.steps(from: subject.spaceID, to: $0.spaceID)!) < abs(layout.steps(from: subject.spaceID, to: $1.spaceID)!) },
                                 "needs a second desktop on the display")
        let mover = WindowMover()

        try mover.move(subject, toSpace: near.spaceID)
        XCTAssertEqual(SpaceReader.spaceIDs(ofWindow: subject.windowID), [near.spaceID])

        // From a hidden desktop: the mover has to go and fetch the window.
        try SpaceSwitcher().go(toSpace: subject.spaceID)
        try mover.move(subject, toSpace: subject.spaceID, frame: subject.frame)
        XCTAssertEqual(SpaceReader.spaceIDs(ofWindow: subject.windowID), [subject.spaceID])

        if let other = layout.displays.first(where: { $0.id != display.id }) {
            try mover.move(subject, toSpace: other.currentSpaceID)
            XCTAssertEqual(SpaceReader.spaceIDs(ofWindow: subject.windowID), [other.currentSpaceID])
            try mover.move(subject, toSpace: subject.spaceID, frame: subject.frame)
            XCTAssertEqual(SpaceReader.spaceIDs(ofWindow: subject.windowID), [subject.spaceID])
        }
        try SpaceSwitcher().go(toSpace: display.currentSpaceID)
    }

    /// With the "Switch to Desktop N" shortcuts enabled, any desktop is one key press away.
    func testDistantDesktopIsReachedAndLeftAgain() throws {
        let layout = try SpaceReader.layout()
        let shortcuts = MissionControlShortcuts.read()
        for display in layout.displays {
            let start = display.currentSpaceID
            let candidates = display.desktops.filter { !$0.isFullscreen && $0.spaceID != start }
            guard let far = candidates.max(by: { abs(layout.steps(from: start, to: $0.spaceID)!) < abs(layout.steps(from: start, to: $1.spaceID)!) }) else { continue }
            let began = Date()
            try SpaceSwitcher(shortcuts: shortcuts).go(toSpace: far.spaceID)
            let elapsed = Date().timeIntervalSince(began)
            XCTAssertEqual(try SpaceReader.layout().display(ofSpace: far.spaceID)?.currentSpaceID, far.spaceID)
            if let ordinal = layout.ordinal(of: far.key), shortcuts.desktop[ordinal] != nil {
                XCTAssertLessThan(elapsed, 3, "direct shortcut for desktop \(ordinal) was not used")
            }
            try SpaceSwitcher(shortcuts: shortcuts).go(toSpace: start)
            XCTAssertEqual(try SpaceReader.layout().display(ofSpace: start)?.currentSpaceID, start)
        }
    }
}
