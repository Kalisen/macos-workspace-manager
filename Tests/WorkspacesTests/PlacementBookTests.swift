import XCTest
@testable import Workspaces

final class PlacementBookTests: XCTestCase {
    let layout = DesktopLayout(displays: [
        Display(id: "A", desktops: [Desktop(spaceID: 1, key: "one"), Desktop(spaceID: 2, key: "two"), Desktop(spaceID: 9, key: "full", isFullscreen: true), Desktop(spaceID: 3, key: "three")], currentSpaceID: 1),
        Display(id: "B", desktops: [Desktop(spaceID: 7, key: "seven")], currentSpaceID: 7),
    ])
    let now = Date(timeIntervalSince1970: 1_000_000)

    func window(_ id: Int, space: Int, title: String = "notes", pid: Int32 = 10, bundle: String = "app.term") -> LiveWindow {
        LiveWindow(windowID: id, pid: pid, bundleID: bundle, appName: "Term", title: title, spaceID: space,
                   frame: WindowFrame(x: 0, y: 0, width: 800, height: 600))
    }

    func testNewWindowIsHomedWhereItIsFirstSeen() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 1), "two")
        XCTAssertTrue(book.displaced([window(1, space: 2)], layout: layout).isEmpty)
    }

    func testUserMoveRehomesWindow() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        book.observe([window(1, space: 3)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testSystemShuffleLeavesWindowDisplaced() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        let shuffled = [window(1, space: 7)]
        book.observe(shuffled, layout: layout, session: "s", trusted: false, now: now)
        book.observe(shuffled, layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 1), "two")
        XCTAssertEqual(book.displaced(shuffled, layout: layout).map(\.home), ["two"])
    }

    func testUserMoveOfDisplacedWindowRehomesIt() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        book.observe([window(1, space: 7)], layout: layout, session: "s", trusted: false, now: now)
        book.observe([window(1, space: 3)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testRehomeMakesWindowDisplacedUntilMoved() {
        var book = PlacementBook()
        let windows = [window(1, space: 2)]
        book.observe(windows, layout: layout, session: "s", trusted: true, now: now)
        book.rehome(windowID: 1, to: "three")
        XCTAssertEqual(book.displaced(windows, layout: layout).map(\.home), ["three"])
        // The move performed by the app must not be mistaken for a user move elsewhere.
        book.observe([window(1, space: 3)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 1), "three")
    }

    func testAcceptCurrentLayoutClearsDisplacements() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        let shuffled = [window(1, space: 7)]
        book.observe(shuffled, layout: layout, session: "s", trusted: false, now: now)
        book.acceptCurrentLayout(shuffled, layout: layout)
        XCTAssertTrue(book.displaced(shuffled, layout: layout).isEmpty)
    }

    func testRebootRebindsWindowsByTitleAndKeepsHome() {
        var book = PlacementBook()
        book.observe([window(1, space: 2, title: "project-a — zsh"), window(2, space: 3, title: "project-b — zsh")],
                     layout: layout, session: "boot1", trusted: true, now: now)
        // After reboot: new IDs and pids, and macOS put both windows on desktop one.
        let after = [window(50, space: 1, title: "project-b — zsh", pid: 99), window(51, space: 1, title: "project-a — zsh", pid: 99)]
        book.observe(after, layout: layout, session: "boot2", trusted: false, now: now)
        XCTAssertEqual(book.home(ofWindow: 50), "three")
        XCTAssertEqual(book.home(ofWindow: 51), "two")
        XCTAssertEqual(book.placements.count, 2)
    }

    func testAppRestartRebindsBySimilarTitle() {
        var book = PlacementBook()
        book.observe([window(1, space: 2, title: "Pull requests · acme/api - Brave")], layout: layout, session: "s", trusted: true, now: now)
        book.observe([window(8, space: 1, title: "Pull requests · acme/api · GitHub - Brave", pid: 77)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 8), "two")
    }

    func testIdenticalTitlesPreferThePlacementWhoseHomeMatches() {
        var book = PlacementBook()
        book.observe([window(1, space: 2, title: "~"), window(2, space: 3, title: "~")], layout: layout, session: "boot1", trusted: true, now: now)
        book.observe([window(60, space: 3, title: "~", pid: 5), window(61, space: 2, title: "~", pid: 5)], layout: layout, session: "boot2", trusted: false, now: now)
        XCTAssertEqual(book.home(ofWindow: 60), "three")
        XCTAssertEqual(book.home(ofWindow: 61), "two")
    }

    func testNewWindowOfRunningAppDoesNotInheritAClosedWindowsHome() {
        var book = PlacementBook()
        book.observe([window(1, space: 2, title: "~")], layout: layout, session: "s", trusted: true, now: now)
        book.observe([window(2, space: 3, title: "~")], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertEqual(book.home(ofWindow: 2), "three")
    }

    func testWindowsOnFullscreenSpacesAreNotTracked() {
        var book = PlacementBook()
        book.observe([window(1, space: 9)], layout: layout, session: "s", trusted: true, now: now)
        XCTAssertTrue(book.placements.isEmpty)
    }

    func testStalePlacementsArePruned() {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        book.observe([], layout: layout, session: "s", trusted: true, now: now.addingTimeInterval(PlacementBook.retention + 1))
        XCTAssertTrue(book.placements.isEmpty)
    }

    func testBookSurvivesPersistence() throws {
        var book = PlacementBook()
        book.observe([window(1, space: 2)], layout: layout, session: "s", trusted: true, now: now)
        let decoded = try JSONDecoder().decode(PlacementBook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(decoded, book)
    }
}

final class DesktopLayoutTests: XCTestCase {
    let layout = DesktopLayout(displays: [
        Display(id: "A", desktops: [Desktop(spaceID: 1, key: "one"), Desktop(spaceID: 9, key: "full", isFullscreen: true), Desktop(spaceID: 3, key: "three")], currentSpaceID: 3),
        Display(id: "B", desktops: [Desktop(spaceID: 7, key: "seven")], currentSpaceID: 7),
    ])

    func testStepsCountFullscreenSpaces() {
        XCTAssertEqual(layout.steps(from: 1, to: 3), 2)
        XCTAssertEqual(layout.steps(from: 3, to: 1), -2)
        XCTAssertNil(layout.steps(from: 1, to: 7))
    }

    func testOrdinalSkipsFullscreenSpacesAndSpansDisplays() {
        XCTAssertEqual(layout.ordinal(of: "three"), 2)
        XCTAssertEqual(layout.ordinal(of: "seven"), 3)
        XCTAssertNil(layout.ordinal(of: "full"))
    }

    func testNamesFallBackToDesktopNumber() {
        var names = WorkspaceNames()
        XCTAssertEqual(names.name(of: "three", in: layout), "Desktop 2")
        names.rename("three", to: "  Billing ")
        XCTAssertEqual(names.name(of: "three", in: layout), "Billing")
        names.rename("three", to: "")
        XCTAssertEqual(names.name(of: "three", in: layout), "Desktop 2")
        XCTAssertEqual(names.name(of: "gone", in: layout), "Missing desktop")
    }
}
