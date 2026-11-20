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

    func testANewRearrangementRestartsIt() {
        var settling = SettlingPeriod()
        settling.systemRearranged(at: someTime)
        settling.systemRearranged(at: someTime.addingTimeInterval(50))
        XCTAssertFalse(settling.isOver(at: someTime.addingTimeInterval(SettlingPeriod.duration + 1)))
    }
}
