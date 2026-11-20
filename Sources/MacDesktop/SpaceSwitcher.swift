import CoreGraphics
import Foundation
import Workspaces

public enum SpaceSwitchError: Error, CustomStringConvertible {
    case unknownSpace(Int)
    case shortcutDisabled(String)
    case didNotSwitch(target: Int, current: Int)

    public var description: String {
        switch self {
        case .unknownSpace(let id): "Desktop \(id) no longer exists"
        case .shortcutDisabled(let name): "The Mission Control shortcut \"\(name)\" is disabled in System Settings > Keyboard > Keyboard Shortcuts"
        case .didNotSwitch(let target, let current): "macOS did not switch to desktop \(target) (still on \(current))"
        }
    }
}

/// Switches the visible Space by pressing the user's Mission Control shortcuts.
/// Every press is verified against the window server, so a wrong or ignored shortcut is detected.
public struct SpaceSwitcher {
    private static let switchTimeout = 2.5
    /// Lets the switch animation finish before the next key press is accepted.
    private static let settle = 0.3

    let shortcuts: MissionControlShortcuts

    public init(shortcuts: MissionControlShortcuts = .read()) {
        self.shortcuts = shortcuts
    }

    /// - Parameter carrying: a window is being dragged, so the cursor is already on the right display.
    public func go(toSpace target: Int, carrying: Bool = false) throws {
        var layout = try SpaceReader.layout()
        guard let display = layout.display(ofSpace: target), let desktop = layout.desktop(spaceID: target) else {
            throw SpaceSwitchError.unknownSpace(target)
        }
        if display.currentSpaceID == target { return }
        // Shortcuts act on the display under the cursor.
        if !carrying, let bounds = SpaceReader.bounds(ofDisplay: display.id), !bounds.contains(SyntheticInput.cursor) {
            CGWarpMouseCursorPosition(CGPoint(x: bounds.midX, y: bounds.midY))
            SyntheticInput.pause(0.05)
        }

        func current() throws -> Int {
            layout = try SpaceReader.layout()
            guard let display = layout.display(ofSpace: target) else { throw SpaceSwitchError.unknownSpace(target) }
            return display.currentSpaceID
        }
        func pressAndWait(_ shortcut: SystemShortcut, from start: Int) throws -> Int {
            SyntheticInput.press(shortcut)
            var now = start
            var failure: Error?
            _ = SyntheticInput.wait(upTo: Self.switchTimeout) {
                do { now = try current() } catch { failure = error; return true }
                return now != start
            }
            if let failure { throw failure }
            if now != start { SyntheticInput.pause(Self.settle) }
            return now
        }

        var position = display.currentSpaceID
        if let ordinal = layout.ordinal(of: desktop.key), let direct = shortcuts.desktop[ordinal] {
            position = try pressAndWait(direct, from: position)
            if position == target { return }
        }
        for _ in 0..<(display.desktops.count * 2) where position != target {
            guard let steps = layout.steps(from: position, to: target) else { throw SpaceSwitchError.unknownSpace(target) }
            guard let shortcut = steps > 0 ? shortcuts.right : shortcuts.left else {
                throw SpaceSwitchError.shortcutDisabled(steps > 0 ? "Move right a space" : "Move left a space")
            }
            let next = try pressAndWait(shortcut, from: position)
            if next == position { throw SpaceSwitchError.didNotSwitch(target: target, current: position) }
            position = next
        }
        if position != target { throw SpaceSwitchError.didNotSwitch(target: target, current: position) }
    }
}
