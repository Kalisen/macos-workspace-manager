import XCTest
@testable import Workspaces

/// Windows get new IDs when their app restarts or the machine reboots; their home must follow.
final class WindowReidentificationTests: XCTestCase {
    var book = PlacementBook()

    func testAfterRebootWindowsKeepTheirHomeAndShowAsDisplaced() {
        book.see([window(1, space: 2, title: "project-a — zsh"), window(2, space: 3, title: "project-b — zsh")])
        // New IDs and pids; macOS reopened both windows on desktop one.
        let reopened = [window(50, space: 1, title: "project-b — zsh", pid: 99), window(51, space: 1, title: "project-a — zsh", pid: 99)]
        book.see(reopened, session: "boot2", trusted: false)
        XCTAssertEqual(book.homes(of: reopened), ["three", "two"])
        XCTAssertEqual(book.placements.count, 2)
        XCTAssertEqual(book.displaced(reopened, layout: twoDisplays).count, 2)
    }

    func testAfterAppRestartAWindowWithASimilarTitleKeepsItsHome() {
        book.see([window(1, space: 2, title: "Pull requests · acme/api - Brave")])
        book.see([window(8, space: 1, title: "Pull requests · acme/api · GitHub - Brave", pid: 77)])
        XCTAssertEqual(book.home(ofWindow: 8), "two")
    }

    func testAWindowWithAnUnrelatedTitleIsANewWindow() {
        book.see([window(1, space: 2, title: "Pull requests · acme/api - Brave")])
        book.see([window(8, space: 1, title: "Weather forecast - Brave", pid: 77)])
        XCTAssertEqual(book.home(ofWindow: 8), "one")
    }

    func testAWindowOfAnotherAppWithTheSameTitleIsANewWindow() {
        book.see([window(1, space: 2, title: "notes")])
        book.see([window(8, space: 1, title: "notes", pid: 77, bundle: "app.editor")])
        XCTAssertEqual(book.home(ofWindow: 8), "one")
    }

    func testAmongIdenticalTitlesAWindowAlreadyOnAHomeTakesThatHome() {
        book.see([window(1, space: 2, title: "~"), window(2, space: 3, title: "~")])
        let reopened = [window(60, space: 3, title: "~", pid: 5), window(61, space: 2, title: "~", pid: 5)]
        book.see(reopened, session: "boot2", trusted: false)
        XCTAssertEqual(book.homes(of: reopened), ["three", "two"])
    }

    /// Titles are empty without the Screen Recording permission.
    func testAWindowWithAnUnreadableTitleDoesNotInheritAnUntitledWindowsHome() {
        book.see([window(1, space: 2, title: "")])
        let reopened = [window(60, space: 3, title: "", pid: 5)]
        book.see(reopened, session: "boot2", trusted: false)
        XCTAssertEqual(book.homes(of: reopened), ["three"])
        XCTAssertTrue(book.displaced(reopened, layout: twoDisplays).isEmpty)
    }

    func testANewWindowOfARunningAppDoesNotInheritAClosedWindowsHome() {
        book.see([window(1, space: 2, title: "~")])
        book.see([window(2, space: 3, title: "~")])
        XCTAssertEqual(book.home(ofWindow: 2), "three")
    }

    func testAWindowIDReusedByAnotherAppIsANewWindow() {
        book.see([window(1, space: 2, title: "notes")])
        book.see([window(1, space: 3, title: "inbox", pid: 77, bundle: "app.mail")])
        XCTAssertEqual(book.placements.filter { $0.bundleID == "app.mail" }.map(\.home), ["three"])
        XCTAssertEqual(book.placements.filter { $0.bundleID == "app.term" }.map(\.home), ["two"])
    }
}
