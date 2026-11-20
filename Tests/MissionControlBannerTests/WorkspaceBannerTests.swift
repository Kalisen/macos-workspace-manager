import AppKit
import XCTest
@testable import MissionControlBanner

final class WorkspaceBannerTests: XCTestCase {
    private let primaryHeight: CGFloat = 1000

    func testLabelIsCentredOnThePrimaryDisplay() {
        let frame = WorkspaceBanner.frame(textSize: CGSize(width: 300, height: 80), displayBounds: CGRect(x: 0, y: 0, width: 2000, height: 1000), primaryHeight: primaryHeight)
        XCTAssertEqual(frame.midX, 1000)
        XCTAssertEqual(frame.midY, 500)
        XCTAssertGreaterThan(frame.width, 300)
    }

    /// A display placed below and to the right of the primary one has negative AppKit y coordinates.
    func testLabelFollowsADisplayPlacedElsewhere() {
        let display = CGRect(x: 2000, y: 400, width: 1000, height: 800)
        let frame = WorkspaceBanner.frame(textSize: CGSize(width: 300, height: 80), displayBounds: display, primaryHeight: primaryHeight)
        XCTAssertEqual(frame.midX, 2500)
        XCTAssertEqual(frame.midY, (primaryHeight - display.maxY) + 400)
    }

    func testLongNameIsLimitedToTheDisplayWidth() {
        let frame = WorkspaceBanner.frame(textSize: CGSize(width: 5000, height: 80), displayBounds: CGRect(x: 0, y: 0, width: 2000, height: 1000), primaryHeight: primaryHeight)
        XCTAssertEqual(frame.width, 1600)
        XCTAssertEqual(frame.midX, 1000)
    }

    func testADisplayShowingAFullscreenSpaceGetsNoLargeName() {
        _ = NSApplication.shared
        let banner = WorkspaceBanner()
        banner.show([WorkspaceLabel(text: "", displayBounds: CGRect(x: 0, y: 0, width: 2000, height: 1000))])
        XCTAssertFalse(banner.isShowing)
    }

    func testOneLabelPerDisplayThatMissionControlLeavesInPlaceAndClicksPassThrough() throws {
        _ = NSApplication.shared
        let banner = WorkspaceBanner()
        banner.show([
            WorkspaceLabel(text: "Billing", displayBounds: CGRect(x: 0, y: 0, width: 2000, height: 1000)),
            WorkspaceLabel(text: "Personal", displayBounds: CGRect(x: 2000, y: 0, width: 1000, height: 800)),
        ])
        XCTAssertEqual(banner.windows.map(\.labelText), ["Billing", "Personal"])
        for window in banner.windows {
            XCTAssertTrue(window.collectionBehavior.contains(.stationary))
            XCTAssertTrue(window.ignoresMouseEvents)
            XCTAssertGreaterThan(window.backgroundAlpha, 0.5, "text needs a contrasting background")
        }
        // A right-click is attributed to the large name under it.
        let second = banner.windows[1].frame
        XCTAssertEqual(banner.index(at: NSPoint(x: second.midX, y: second.midY)), 1)
        XCTAssertNil(banner.index(at: NSPoint(x: second.maxX + 50, y: second.midY)))
        banner.hide()
        XCTAssertFalse(banner.isShowing)
    }
}
