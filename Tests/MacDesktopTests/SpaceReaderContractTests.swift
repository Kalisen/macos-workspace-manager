import AppKit
import XCTest
@testable import MacDesktop

/// Read-only checks against the running system: they fail when a macOS release changes the private
/// window-server data the app depends on.
final class SpaceReaderContractTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no display attached")
    }

    func testEveryDisplayShowsOneOfItsOwnDesktops() throws {
        let layout = try SpaceReader.layout()
        XCTAssertFalse(layout.displays.isEmpty)
        for display in layout.displays {
            XCTAssertTrue(display.desktops.contains { $0.spaceID == display.currentSpaceID }, "display \(display.id)")
            XCTAssertNotNil(SpaceReader.bounds(ofDisplay: display.id), "display \(display.id) has no screen")
        }
    }

    func testWorkspaceKeysAreUnique() throws {
        let keys = try SpaceReader.layout().workspaces.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testTrackedWindowsSitOnExactlyOneKnownWorkspace() throws {
        let layout = try SpaceReader.layout()
        for window in WindowReader.windows(in: layout) {
            XCTAssertNotNil(layout.key(ofSpace: window.spaceID), "\(window.appName) window \(window.windowID)")
            XCTAssertEqual(SpaceReader.spaceIDs(ofWindow: window.windowID).count, 1)
        }
    }

    func testBootSessionIsStableWithinABoot() {
        XCTAssertFalse(SpaceReader.bootSession().isEmpty)
        XCTAssertEqual(SpaceReader.bootSession(), SpaceReader.bootSession())
    }
}
