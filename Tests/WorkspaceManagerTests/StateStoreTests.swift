import Workspaces
import XCTest
@testable import WorkspaceManager

final class StateStoreTests: XCTestCase {
    private var file: URL!

    override func setUp() {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("wm-tests-\(UUID().uuidString)/state.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    func testNothingSavedYetIsAnEmptyState() throws {
        XCTAssertEqual(try StateStore.load(from: file), WorkspaceState())
    }

    func testNamesAndPlacementsSurviveARestart() throws {
        let layout = DesktopLayout(displays: [Display(id: "A", desktops: [Desktop(spaceID: 1, key: "one")], currentSpaceID: 1)])
        var state = WorkspaceState()
        state.names.rename("one", to: "Billing")
        state.book.observe(
            [LiveWindow(windowID: 4, pid: 9, bundleID: "app.term", appName: "Term", title: "notes", spaceID: 1,
                        frame: WindowFrame(x: 1, y: 2, width: 300, height: 200))],
            layout: layout, session: "boot1", trusted: true, now: Date(timeIntervalSince1970: 1_000_000))
        try StateStore.save(state, to: file)
        XCTAssertEqual(try StateStore.load(from: file), state)
    }

    func testAnUnreadableFileIsAnErrorAndCanBeSetAside() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{ not json".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try StateStore.load(from: file))
        let kept = try StateStore.quarantine(file)
        XCTAssertEqual(try String(contentsOf: kept, encoding: .utf8), "{ not json")
        XCTAssertEqual(try StateStore.load(from: file), WorkspaceState())
    }
}
