import XCTest
@testable import WorkspaceManager

final class SettingsTests: XCTestCase {
    private var file: URL!

    override func setUp() {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("wm-tests-\(UUID().uuidString)/config.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    private func write(_ json: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: file, atomically: true, encoding: .utf8)
    }

    func testFirstLaunchWritesTheDefaults() throws {
        XCTAssertEqual(try Settings.load(from: file), Settings())
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: Data(contentsOf: file)), Settings())
    }

    func testKeysMissingFromTheFileKeepTheirDefault() throws {
        try write(#"{"shortcuts": {"restoreWindows": "cmd+f5"}, "titleBarMenu": {"modifiers": "ctrl"}}"#)
        let settings = try Settings.load(from: file)
        XCTAssertEqual(settings.shortcuts.restoreWindows, "cmd+f5")
        XCTAssertEqual(settings.shortcuts.switchWorkspace, Settings().shortcuts.switchWorkspace)
        XCTAssertEqual(settings.titleBarMenu.modifiers, "ctrl")
        XCTAssertEqual(settings.titleBarMenu.height, Settings().titleBarMenu.height)
        XCTAssertTrue(settings.missionControlBanner.enabled)
        XCTAssertTrue(settings.missionControlBanner.desktopLabels)
    }

    func testAMalformedFileIsAnError() throws {
        try write("{ not json")
        XCTAssertThrowsError(try Settings.load(from: file))
    }
}
