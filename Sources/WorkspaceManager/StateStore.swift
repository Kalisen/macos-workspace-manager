import Foundation
import Workspaces

/// Workspace names and window placements, persisted across restarts and reboots.
struct WorkspaceState: Codable, Equatable {
    var names = WorkspaceNames()
    var book = PlacementBook()
}

enum StateStore {
    static let file = Settings.directory.appendingPathComponent("state.json")

    /// Empty state when nothing was saved yet.
    static func load(from file: URL = file) throws -> WorkspaceState {
        guard FileManager.default.fileExists(atPath: file.path) else { return WorkspaceState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkspaceState.self, from: Data(contentsOf: file))
    }

    static func save(_ state: WorkspaceState, to file: URL = file) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: file, options: .atomic)
    }

    /// Moves an unreadable state file aside so it is not overwritten.
    static func quarantine(_ file: URL = file) throws -> URL {
        let target = file.deletingLastPathComponent().appendingPathComponent("state.unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try FileManager.default.moveItem(at: file, to: target)
        return target
    }
}
