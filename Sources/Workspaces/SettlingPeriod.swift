import Foundation

/// The time after a wake or display change during which macOS may still be shuffling windows by itself.
/// Window moves observed inside it are not attributed to the user.
public struct SettlingPeriod: Sendable {
    public static let duration: TimeInterval = 60

    private var until: Date

    /// Starts settled.
    public init() {
        until = .distantPast
    }

    public mutating func systemRearranged(at date: Date) {
        until = date.addingTimeInterval(Self.duration)
    }

    /// Starts the period when the displays differ between two consecutive observations. macOS moves
    /// windows as a display comes or goes, and an observation can see that before the notification arrives.
    /// - Returns: whether the displays changed.
    public mutating func displaysChanged(from previous: DesktopLayout, to layout: DesktopLayout, at date: Date) -> Bool {
        guard previous.displays.map(\.id) != layout.displays.map(\.id) else { return false }
        systemRearranged(at: date)
        return true
    }

    public func isOver(at date: Date) -> Bool {
        date > until
    }
}
