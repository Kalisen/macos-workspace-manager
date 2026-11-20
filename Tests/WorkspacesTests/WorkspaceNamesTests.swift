import XCTest
@testable import Workspaces

final class WorkspaceNamesTests: XCTestCase {
    var names = WorkspaceNames()

    func testUnnamedWorkspaceIsCalledByItsDesktopNumber() {
        XCTAssertEqual(names.name(of: "three", in: twoDisplays), "Desktop 3")
    }

    func testRenamingTrimsAndAnEmptyNameRestoresTheDefault() {
        names.rename("three", to: "  Billing ")
        XCTAssertEqual(names.name(of: "three", in: twoDisplays), "Billing")
        XCTAssertEqual(names.customName(of: "three"), "Billing")
        names.rename("three", to: "  ")
        XCTAssertNil(names.customName(of: "three"))
        XCTAssertEqual(names.name(of: "three", in: twoDisplays), "Desktop 3")
    }

    func testANameOutlivesItsDesktopLeavingTheLayout() {
        names.rename("gone", to: "Archive")
        XCTAssertEqual(names.name(of: "gone", in: twoDisplays), "Archive")
        XCTAssertEqual(names.name(of: "never-named", in: twoDisplays), "Missing desktop")
    }

    func testNamesSurviveEncoding() throws {
        names.rename("three", to: "Billing")
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceNames.self, from: JSONEncoder().encode(names)), names)
    }
}
