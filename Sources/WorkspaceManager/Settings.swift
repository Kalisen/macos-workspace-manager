import Foundation
import MacDesktop

/// User configuration, stored as `config.json` next to the state file.
struct Settings: Codable, Equatable {
    struct Shortcuts: Codable, Equatable {
        /// Opens the workspace list to jump to a workspace.
        var switchWorkspace = "ctrl+alt+space"
        /// Opens the workspace list to send the focused window to a workspace.
        var sendWindow = "ctrl+alt+shift+space"
        /// Moves every displaced window back to its workspace.
        var restoreWindows = "ctrl+alt+r"

        init() {}

        /// Keys missing from the file keep their default.
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            switchWorkspace = try values.decodeIfPresent(String.self, forKey: .switchWorkspace) ?? switchWorkspace
            sendWindow = try values.decodeIfPresent(String.self, forKey: .sendWindow) ?? sendWindow
            restoreWindows = try values.decodeIfPresent(String.self, forKey: .restoreWindows) ?? restoreWindows
        }
    }

    struct TitleBarMenu: Codable, Equatable {
        /// Modifiers held while right-clicking a window title bar to open the "send to workspace" menu.
        var modifiers = "alt+shift"
        /// Height in points of the zone, from the top of the window, that counts as title bar.
        var height = 40.0

        init() {}

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            modifiers = try values.decodeIfPresent(String.self, forKey: .modifiers) ?? modifiers
            height = try values.decodeIfPresent(Double.self, forKey: .height) ?? height
        }
    }

    var shortcuts = Shortcuts()
    var titleBarMenu = TitleBarMenu()

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shortcuts = try values.decodeIfPresent(Shortcuts.self, forKey: .shortcuts) ?? shortcuts
        titleBarMenu = try values.decodeIfPresent(TitleBarMenu.self, forKey: .titleBarMenu) ?? titleBarMenu
    }

    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("WorkspaceManager", isDirectory: true)
    static let file = directory.appendingPathComponent("config.json")

    /// Reads the configuration, creating the file with defaults on first launch.
    static func load(from file: URL = file) throws -> Settings {
        guard FileManager.default.fileExists(atPath: file.path) else {
            let defaults = Settings()
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(defaults).write(to: file, options: .atomic)
            return defaults
        }
        return try JSONDecoder().decode(Settings.self, from: Data(contentsOf: file))
    }
}
