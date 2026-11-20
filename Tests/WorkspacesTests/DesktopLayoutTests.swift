import XCTest
@testable import Workspaces

final class DesktopLayoutTests: XCTestCase {
    func testStepsBetweenDesktopsCountFullscreenSpaces() {
        XCTAssertEqual(twoDisplays.steps(from: 1, to: 3), 3)
        XCTAssertEqual(twoDisplays.steps(from: 3, to: 2), -2)
    }

    func testNoStepsBetweenDisplays() {
        XCTAssertNil(twoDisplays.steps(from: 1, to: 7))
    }

    func testOrdinalSkipsFullscreenSpacesAndContinuesAcrossDisplays() {
        XCTAssertEqual(twoDisplays.ordinal(of: "three"), 3)
        XCTAssertEqual(twoDisplays.ordinal(of: "seven"), 4)
        XCTAssertNil(twoDisplays.ordinal(of: "full"))
    }

    func testFullscreenSpacesAreNotWorkspaces() {
        XCTAssertEqual(twoDisplays.workspaces.map(\.key), ["one", "two", "three", "seven"])
        XCTAssertNil(twoDisplays.key(ofSpace: 9))
        XCTAssertNil(twoDisplays.desktop(key: "full"))
    }

    func testDisplayOfASpace() {
        XCTAssertEqual(twoDisplays.display(ofSpace: 7)?.id, "B")
        XCTAssertNil(twoDisplays.display(ofSpace: 404))
    }
}
