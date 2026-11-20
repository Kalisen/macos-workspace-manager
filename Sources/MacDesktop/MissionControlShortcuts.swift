import AppKit

/// A key press as macOS stores it for its own shortcuts: key code plus raw modifier flags.
public struct SystemShortcut: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public let flags: CGEventFlags
}

/// The user's Mission Control keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts > Mission Control).
public struct MissionControlShortcuts: Sendable {
    /// "Move left a space"; nil when disabled.
    public let left: SystemShortcut?
    /// "Move right a space"; nil when disabled.
    public let right: SystemShortcut?
    /// "Switch to Desktop N" by N; only the enabled ones.
    public let desktop: [Int: SystemShortcut]

    private static let leftID = 79, rightID = 81, firstDesktopID = 118, desktopCount = 16
    private static let controlArrow = CGEventFlags([.maskControl, .maskSecondaryFn, .maskNumericPad])

    public static func read() -> MissionControlShortcuts {
        MissionControlShortcuts(stored: UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:])
    }

    /// - Parameter stored: the `AppleSymbolicHotKeys` preference. macOS omits entries the user never changed:
    ///   the left/right shortcuts are then on with their default keys, the "Switch to Desktop N" ones are off.
    init(stored: [String: Any]) {
        func shortcut(_ id: Int, default fallback: SystemShortcut?) -> SystemShortcut? {
            guard let entry = stored[String(id)] as? [String: Any] else { return fallback }
            guard (entry["enabled"] as? Bool) == true else { return nil }
            guard let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int], parameters.count == 3 else { return fallback }
            return SystemShortcut(keyCode: CGKeyCode(parameters[1]), flags: CGEventFlags(rawValue: UInt64(parameters[2])))
        }
        var desktop: [Int: SystemShortcut] = [:]
        for n in 1...Self.desktopCount {
            desktop[n] = shortcut(Self.firstDesktopID + n - 1, default: nil)
        }
        left = shortcut(Self.leftID, default: SystemShortcut(keyCode: 123, flags: Self.controlArrow))
        right = shortcut(Self.rightID, default: SystemShortcut(keyCode: 124, flags: Self.controlArrow))
        self.desktop = desktop
    }
}
