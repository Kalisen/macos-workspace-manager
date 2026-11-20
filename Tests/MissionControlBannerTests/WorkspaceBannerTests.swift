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

    func testOneLabelPerDisplayThatMissionControlLeavesInPlaceAndClicksPassThrough() throws {
        _ = NSApplication.shared
        let banner = WorkspaceBanner()
        banner.show([
            WorkspaceLabel(text: "Billing", displayBounds: CGRect(x: 0, y: 0, width: 2000, height: 1000)),
            WorkspaceLabel(text: "Personal", displayBounds: CGRect(x: 2000, y: 0, width: 1000, height: 800)),
        ])
        XCTAssertEqual(banner.windows.count, 2)
        for window in banner.windows {
            XCTAssertTrue(window.collectionBehavior.contains(.stationary))
            XCTAssertTrue(window.ignoresMouseEvents)
            let background = try XCTUnwrap(window.contentView?.layer?.backgroundColor, "text needs a contrasting background")
            XCTAssertGreaterThan(background.alpha, 0.5)
        }
        banner.hide()
        XCTAssertFalse(banner.isShowing)
    }
}
