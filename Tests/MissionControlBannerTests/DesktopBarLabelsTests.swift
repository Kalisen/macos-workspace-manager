import XCTest
@testable import MissionControlBanner

/// Frames are those the Dock reports on macOS 26 for a 7680-point-wide display.
final class DesktopBarLabelsTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 7680, height: 2160)
    /// Names only: reported one bar-height above the bar.
    private var collapsed: DesktopBar {
        DesktopBar(displayFrame: display, frame: CGRect(x: 0, y: 0, width: 7680, height: 40),
                   desktops: [CGRect(x: 3091, y: -32, width: 65, height: 24), CGRect(x: 3188, y: -32, width: 67, height: 24), CGRect(x: 3287, y: -32, width: 68, height: 24)])
    }
    private var expanded: DesktopBar {
        DesktopBar(displayFrame: display, frame: CGRect(x: 0, y: 0, width: 7680, height: 146),
                   desktops: [CGRect(x: 1216, y: 28, width: 320, height: 90), CGRect(x: 1568, y: 28, width: 320, height: 90), CGRect(x: 1920, y: 28, width: 320, height: 90)])
    }
    private let tenPerCharacter: (String, CGFloat) -> CGFloat = { text, _ in CGFloat(text.count) * 10 }

    func testCollapsedBarNameIsReplacedWhereTheDockDrawsIt() {
        XCTAssertEqual(collapsed.slot(1), .name(CGRect(x: 3188, y: 8, width: 67, height: 24)))
        let labels = DesktopBarLabels.labels(for: collapsed, names: [nil, "Bill", nil], textWidth: tenPerCharacter)
        XCTAssertEqual(labels.map(\.text), ["Bill"])
        XCTAssertEqual(labels[0].frame.midX, 3221.5)
        XCTAssertEqual(labels[0].frame.minY, 8)
        XCTAssertEqual(labels[0].frame.height, 24)
    }

    func testExpandedBarLabelSitsInTheMiddleOfThePreview() {
        XCTAssertEqual(expanded.slot(0), .preview(CGRect(x: 1216, y: 28, width: 320, height: 90)))
        let labels = DesktopBarLabels.labels(for: expanded, names: ["Billing", nil, "Personal"], textWidth: tenPerCharacter)
        XCTAssertEqual(labels.map(\.text), ["Billing", "Personal"])
        XCTAssertEqual(labels[0].frame.midX, 1376)
        XCTAssertEqual(labels[0].frame.midY, 73)
        XCTAssertGreaterThan(labels[0].fontSize, 12)
    }

    func testALongNameStaysWithinItsDesktop() {
        let long = String(repeating: "x", count: 80)
        let inName = DesktopBarLabels.labels(for: collapsed, names: [nil, long, nil], textWidth: tenPerCharacter)[0]
        XCTAssertLessThan(inName.frame.width, collapsed.spacing(around: 1))
        let inPreview = DesktopBarLabels.labels(for: expanded, names: [long, nil, nil], textWidth: tenPerCharacter)[0]
        XCTAssertLessThan(inPreview.frame.width, 320)
    }

    func testABarThatDoesNotMatchTheDesktopsIsLeftUnlabelled() {
        XCTAssertTrue(DesktopBarLabels.labels(for: expanded, names: ["Billing", "Personal"], textWidth: tenPerCharacter).isEmpty)
    }

    func testADesktopReportedOutsideTheBarIsLeftUnlabelled() {
        let odd = DesktopBar(displayFrame: display, frame: CGRect(x: 0, y: 0, width: 7680, height: 40), desktops: [CGRect(x: 100, y: 500, width: 65, height: 24)])
        XCTAssertNil(odd.slot(0))
        XCTAssertTrue(DesktopBarLabels.labels(for: odd, names: ["Billing"], textWidth: tenPerCharacter).isEmpty)
    }

    // MARK: Right-click target

    private func labels(_ desktops: [WorkspaceLabel.Desktop]) -> [WorkspaceLabel] {
        [WorkspaceLabel(text: "Billing", currentID: "b", displayBounds: display, desktops: desktops)]
    }
    private let three: [WorkspaceLabel.Desktop] = [.init(id: "a", name: "Billing"), .init(id: "b", name: nil), .init(id: nil, name: nil)]

    func testAPointOnADesktopOfTheBarNamesThatDesktopWhetherLabelledOrNot() {
        XCTAssertEqual(MissionControlOverlay.workspace(at: CGPoint(x: 1300, y: 60), bars: [expanded], labels: labels(three)), "a")
        XCTAssertEqual(MissionControlOverlay.workspace(at: CGPoint(x: 1700, y: 60), bars: [expanded], labels: labels(three)), "b")
        // Collapsed: where the name is drawn, not where the Dock reports it.
        XCTAssertEqual(MissionControlOverlay.workspace(at: CGPoint(x: 3200, y: 20), bars: [collapsed], labels: labels(three)), "b")
    }

    func testAPointElsewhereOrOnAFullscreenSpaceNamesNothing() {
        XCTAssertNil(MissionControlOverlay.workspace(at: CGPoint(x: 1550, y: 60), bars: [expanded], labels: labels(three)))
        XCTAssertNil(MissionControlOverlay.workspace(at: CGPoint(x: 1300, y: 600), bars: [expanded], labels: labels(three)))
        XCTAssertNil(MissionControlOverlay.workspace(at: CGPoint(x: 2000, y: 60), bars: [expanded], labels: labels(three)))
    }

    func testABarThatDoesNotMatchTheDesktopsNamesNothing() {
        XCTAssertNil(MissionControlOverlay.workspace(at: CGPoint(x: 1300, y: 60), bars: [expanded], labels: labels(Array(three.prefix(2)))))
    }
}
