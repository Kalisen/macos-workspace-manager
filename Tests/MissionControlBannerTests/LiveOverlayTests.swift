import AppKit
import XCTest
@testable import MissionControlBanner

/// Opens Mission Control for real. Runs on request: `WORKSPACE_MANAGER_LIVE=1 swift test --filter LiveOverlayTests`.
final class LiveOverlayTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WORKSPACE_MANAGER_LIVE"] == "1", "live desktop test not requested")
        try XCTSkipUnless(AXIsProcessTrusted(), "Accessibility permission missing")
        _ = NSApplication.shared
    }

    private func toggleMissionControl() throws {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "Mission Control"]
        try open.run()
        open.waitUntilExit()
    }

    private func spin(upTo timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        return condition()
    }

    /// Windows that are on screen at full size, i.e. not turned into Mission Control thumbnails.
    private func onScreen(_ windowNumbers: [Int]) -> Bool {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let visible = Set(list.compactMap { $0[kCGWindowNumber as String] as? Int })
        return !windowNumbers.isEmpty && windowNumbers.allSatisfy(visible.contains)
    }

    func testLabelShowsWhileMissionControlIsOpenAndOnlyThen() throws {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        var overlay: MissionControlOverlay!
        overlay = MissionControlOverlay {
            // Every desktop of the main display gets a name, however many there are.
            let desktops = overlay.watcher.desktopBars?.first { $0.displayFrame.origin == bounds.origin }?.desktops.count ?? 0
            return [WorkspaceLabel(text: "Live test", displayBounds: bounds, desktopNames: Array(repeating: "Live", count: desktops))]
        }
        try overlay.start()
        XCTAssertFalse(overlay.isShowing)

        try toggleMissionControl()
        addTeardownBlock { if overlay.isShowing { try self.toggleMissionControl() } }
        XCTAssertTrue(spin(upTo: 3) { overlay.isShowing }, "opening Mission Control was not detected")
        XCTAssertTrue(spin(upTo: 2) { self.onScreen(overlay.windowNumbers) }, "label is not on screen")
        XCTAssertTrue(spin(upTo: 3) { self.onScreen(overlay.desktopLabelWindowNumbers) }, "desktops of the bar are not labelled")
        let desktops = overlay.watcher.desktopBars?.first { $0.displayFrame.origin == bounds.origin }?.desktops.count
        XCTAssertEqual(overlay.desktopLabelWindowNumbers.count, desktops)

        try toggleMissionControl()
        XCTAssertTrue(spin(upTo: 3) { !overlay.isShowing }, "closing Mission Control was not detected")
        XCTAssertTrue(overlay.desktopLabelWindowNumbers.isEmpty)
    }
}
