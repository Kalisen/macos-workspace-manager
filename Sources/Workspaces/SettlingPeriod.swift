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

    public func isOver(at date: Date) -> Bool {
        date > until
    }
}
