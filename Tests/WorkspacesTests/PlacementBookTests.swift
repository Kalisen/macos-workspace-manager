import XCTest
@testable import Workspaces

/// Which workspace a window belongs to, and when it counts as displaced.
final class PlacementBookTests: XCTestCase {
    var book = PlacementBook()

    func testWindowIsHomedWhereItIsFirstSeen() {
        book.see([window(1, space: 2)])
        XCTAssertEqual(book.home(ofWindow: 1), "two")
        XCTAssertTrue(book.displaced([window(1, space: 2)], layout: twoDisplays).isEmpty)
    }

    func testUserMoveRehomesWindow() {
        book.see([window(1, space: 2)])
        book.see([window(1, space: 3)])
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testMoveDuringSettlingLeavesWindowDisplacedWithItsHomeFrame() {
        book.see([window(1, space: 2, frame: frameA)])
        let shuffled = [window(1, space: 7, frame: frameB)]
        book.see(shuffled, trusted: false)
        // Staying put afterwards is not a user move either.
        book.see(shuffled, trusted: true)
        let displaced = book.displaced(shuffled, layout: twoDisplays)
        XCTAssertEqual(displaced.map(\.home), ["two"])
        XCTAssertEqual(displaced.map(\.homeFrame), [frameA])
    }

    func testMoveSeenJustBeforeSettlingIsUndone() {
        book.see([window(1, space: 7, frame: frameA)])
        let shuffled = [window(1, space: 2, frame: frameB)]
        book.see(shuffled)
        book.see(shuffled, trusted: false, at: someTime.addingTimeInterval(PlacementBook.rehomeConfirmation))
        let displaced = book.displaced(shuffled, layout: twoDisplays)
        XCTAssertEqual(displaced.map(\.home), ["seven"])
        XCTAssertEqual(displaced.map(\.homeFrame), [frameA])
    }

    func testMoveSeenWellBeforeSettlingStands() {
        book.see([window(1, space: 7)])
        book.see([window(1, space: 2)])
        book.see([window(1, space: 2)], trusted: false, at: someTime.addingTimeInterval(PlacementBook.rehomeConfirmation + 1))
        XCTAssertEqual(book.home(ofWindow: 1), "two")
    }

    func testSendingAWindowJustBeforeSettlingStands() {
        book.see([window(1, space: 2)])
        book.see([window(1, space: 3)])
        book.rehome(windowID: 1, to: "seven")
        book.see([window(1, space: 7)], trusted: false)
        XCTAssertEqual(book.home(ofWindow: 1), "seven")
    }

    func testKeepingTheCurrentLayoutJustBeforeSettlingStands() {
        book.see([window(1, space: 2)])
        let moved = [window(1, space: 3)]
        book.see(moved)
        book.acceptCurrentLayout(moved, layout: twoDisplays)
        book.see(moved, trusted: false)
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    /// A window is out of sight while minimized, hidden, fullscreen or dragged between desktops.
    func testMoveOfWindowThatWentOutOfSightRehomesIt() {
        book.see([window(1, space: 2)])
        book.see([])
        book.see([window(1, space: 3)])
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testWindowOutOfSightDuringSettlingIsDisplacedWhenItReturnsElsewhere() {
        book.see([window(1, space: 2)])
        book.see([], trusted: false)
        book.see([window(1, space: 7)])
        XCTAssertEqual(book.home(ofWindow: 1), "two")
    }

    func testUserMoveOfDisplacedWindowRehomesIt() {
        book.see([window(1, space: 2)])
        book.see([window(1, space: 7)], trusted: false)
        book.see([window(1, space: 3)])
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testResizingAtHomeUpdatesTheHomeFrame() {
        book.see([window(1, space: 2, frame: frameA)])
        book.see([window(1, space: 2, frame: frameB)])
        book.rehome(windowID: 1, to: "three")
        XCTAssertEqual(book.displaced([window(1, space: 2, frame: frameB)], layout: twoDisplays).map(\.homeFrame), [frameB])
    }

    func testSendingAWindowMakesItDisplacedUntilItArrives() {
        let windows = [window(1, space: 2)]
        book.see(windows)
        book.rehome(windowID: 1, to: "three")
        XCTAssertEqual(book.displaced(windows, layout: twoDisplays).map(\.home), ["three"])
        book.see([window(1, space: 3)])
        XCTAssertEqual(book.home(ofWindow: 1), "three")
        XCTAssertTrue(book.displaced([window(1, space: 3)], layout: twoDisplays).isEmpty)
    }

    func testKeepingTheCurrentLayoutClearsDisplacements() {
        book.see([window(1, space: 2)])
        let shuffled = [window(1, space: 7)]
        book.see(shuffled, trusted: false)
        book.acceptCurrentLayout(shuffled, layout: twoDisplays)
        XCTAssertTrue(book.displaced(shuffled, layout: twoDisplays).isEmpty)
        XCTAssertEqual(book.home(ofWindow: 1), "seven")
    }

    func testWindowStaysDisplacedWhenItsHomeDesktopWasRemoved() {
        book.see([window(1, space: 2)])
        let withoutTwo = DesktopLayout(displays: [Display(id: "A", desktops: [Desktop(spaceID: 1, key: "one")], currentSpaceID: 1)])
        let moved = [window(1, space: 1)]
        book.observe(moved, layout: withoutTwo, session: "boot1", trusted: false, now: someTime)
        XCTAssertEqual(book.displaced(moved, layout: withoutTwo).map(\.home), ["two"])
        XCTAssertNil(withoutTwo.desktop(key: "two"))
    }

    func testWindowsOnFullscreenSpacesAreNotTracked() {
        book.see([window(1, space: 9)])
        XCTAssertTrue(book.placements.isEmpty)
    }

    func testWindowCountPerWorkspace() {
        let windows = [window(1, space: 2), window(2, space: 2), window(3, space: 7)]
        XCTAssertEqual(book.windowCount(on: "two", among: windows, layout: twoDisplays), 2)
        XCTAssertEqual(book.windowCount(on: "one", among: windows, layout: twoDisplays), 0)
    }

    func testPlacementsOfWindowsUnseenForTheRetentionPeriodAreDropped() {
        book.see([window(1, space: 2), window(2, space: 3)])
        book.see([window(2, space: 3)], at: someTime.addingTimeInterval(PlacementBook.retention + 1))
        XCTAssertEqual(book.placements.map(\.windowID), [2])
    }

    func testBookSurvivesEncoding() throws {
        book.see([window(1, space: 2)])
        XCTAssertEqual(try JSONDecoder().decode(PlacementBook.self, from: JSONEncoder().encode(book)), book)
    }
}
