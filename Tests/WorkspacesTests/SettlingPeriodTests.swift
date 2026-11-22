import XCTest
@testable import Workspaces

final class SettlingPeriodTests: XCTestCase {
    func testSettledUntilTheSystemRearranges() {
        XCTAssertTrue(SettlingPeriod().isOver(at: someTime))
    }

    func testLastsForItsDurationAfterARearrangement() {
        var settling = SettlingPeriod()
        settling.systemRearranged(at: someTime)
        XCTAssertFalse(settling.isOver(at: someTime.addingTimeInterval(SettlingPeriod.duration - 1)))
        XCTAssertTrue(settling.isOver(at: someTime.addingTimeInterval(SettlingPeriod.duration + 1)))
    }

    func testADisplayGoingAwayStartsIt() {
        var settling = SettlingPeriod()
        let oneDisplay = DesktopLayout(displays: [twoDisplays.displays[0]])
        XCTAssertTrue(settling.displaysChanged(from: twoDisplays, to: oneDisplay, at: someTime))
        XCTAssertFalse(settling.isOver(at: someTime.addingTimeInterval(1)))
    }

    func testUnchangedDisplaysDoNotStartIt() {
        var settling = SettlingPeriod()
        XCTAssertFalse(settling.displaysChanged(from: twoDisplays, to: twoDisplays, at: someTime))
        XCTAssertTrue(settling.isOver(at: someTime))
    }

    func testANewRearrangementRestartsIt() {
        var settling = SettlingPeriod()
        settling.systemRearranged(at: someTime)
        settling.systemRearranged(at: someTime.addingTimeInterval(50))
        XCTAssertFalse(settling.isOver(at: someTime.addingTimeInterval(SettlingPeriod.duration + 1)))
    }
}
