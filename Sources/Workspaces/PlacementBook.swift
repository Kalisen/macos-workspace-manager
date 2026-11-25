import Foundation

/// The workspace a window belongs to, as last decided by the user.
public struct Placement: Codable, Equatable, Sendable {
    /// 0 when the window is not currently identified (new boot session).
    public var windowID: Int
    public var pid: Int32
    public let bundleID: String
    public var appName: String
    public var title: String
    public var home: WorkspaceKey
    public var frame: WindowFrame
    public var lastSeen: Date
}

/// A window that is not on its home workspace.
public struct Displacement: Equatable, Sendable {
    public let window: LiveWindow
    public let home: WorkspaceKey
    public let homeFrame: WindowFrame
}

/// Remembers the home workspace of every window and detects windows that left it.
///
/// A window's home follows the user: moving a window to another desktop re-homes it.
/// Moves seen while `trusted` is false (after wake or a display change, when macOS
/// shuffles windows by itself) do not re-home, so the window shows up as displaced.
/// macOS can start shuffling before the caller knows about it, so a re-home is undone when
/// an untrusted observation follows it within `rehomeConfirmation`.
public struct PlacementBook: Codable, Equatable, Sendable {
    static let retention: TimeInterval = 30 * 24 * 3600
    static let lastSeenGranularity: TimeInterval = 3600
    /// Longest delay between macOS moving windows and the caller learning that it rearranged them.
    static let rehomeConfirmation: TimeInterval = 10

    /// What a re-home replaced, kept until the re-home is confirmed.
    private struct PreviousHome: Sendable {
        let home: WorkspaceKey
        let frame: WindowFrame
        let rehomedAt: Date
    }

    /// Identifies the boot session; window IDs are only meaningful within one.
    public private(set) var session: String
    public private(set) var placements: [Placement]
    /// Where each window was last observed. Kept while a window is out of sight (minimized, hidden,
    /// fullscreen, mid-drag between desktops) so that its return elsewhere is seen as a move.
    private var lastObserved: [Int: WorkspaceKey] = [:]
    private var unconfirmedRehomes: [Int: PreviousHome] = [:]

    private enum CodingKeys: String, CodingKey { case session, placements }

    public init(session: String = "", placements: [Placement] = []) {
        self.session = session
        self.placements = placements
    }

    public static func == (a: PlacementBook, b: PlacementBook) -> Bool {
        a.session == b.session && a.placements == b.placements
    }

    public mutating func observe(_ windows: [LiveWindow], layout: DesktopLayout, session: String, trusted: Bool, now: Date) {
        if session != self.session {
            self.session = session
            lastObserved = [:]
            unconfirmedRehomes = [:]
            for i in placements.indices {
                placements[i].windowID = 0
                placements[i].pid = 0
            }
        }

        unconfirmedRehomes = unconfirmedRehomes.filter { now.timeIntervalSince($0.value.rehomedAt) <= Self.rehomeConfirmation }
        if !trusted {
            for (windowID, previous) in unconfirmedRehomes {
                guard let i = placements.firstIndex(where: { $0.windowID == windowID }) else { continue }
                placements[i].home = previous.home
                placements[i].frame = previous.frame
            }
            unconfirmedRehomes = [:]
        }

        var indexByWindowID: [Int: Int] = [:]
        for (i, placement) in placements.enumerated() where placement.windowID != 0 {
            indexByWindowID[placement.windowID] = i
        }
        var bound: [(window: LiveWindow, placement: Int)] = []
        var unidentified: [LiveWindow] = []
        for window in windows {
            if let i = indexByWindowID[window.windowID], placements[i].bundleID == window.bundleID {
                bound.append((window, i))
            } else {
                unidentified.append(window)
            }
        }

        let boundPlacements = Set(bound.map(\.placement))
        let free = placements.indices.filter { !boundPlacements.contains($0) }
        let pairs = WindowMatching.pair(windows: unidentified, placements: free.map { placements[$0] }) {
            layout.key(ofSpace: $0.spaceID)
        }
        var rebound = Set<Int>()
        for pair in pairs {
            let window = unidentified[pair.window], i = free[pair.placement]
            placements[i].windowID = window.windowID
            placements[i].pid = window.pid
            lastObserved[window.windowID] = nil
            bound.append((window, i))
            rebound.insert(pair.window)
        }

        for (w, window) in unidentified.enumerated() where !rebound.contains(w) {
            guard let key = layout.key(ofSpace: window.spaceID) else { continue }
            placements.append(Placement(
                windowID: window.windowID, pid: window.pid, bundleID: window.bundleID, appName: window.appName,
                title: window.title, home: key, frame: window.frame, lastSeen: now))
            lastObserved[window.windowID] = key
        }

        for (window, i) in bound {
            guard let key = layout.key(ofSpace: window.spaceID) else { continue }
            if trusted, let previous = lastObserved[window.windowID], previous != key, placements[i].home != key {
                if unconfirmedRehomes[window.windowID] == nil {
                    unconfirmedRehomes[window.windowID] = PreviousHome(home: placements[i].home, frame: placements[i].frame, rehomedAt: now)
                }
                placements[i].home = key
            }
            if trusted, placements[i].home == key {
                placements[i].frame = window.frame
            }
            if !window.title.isEmpty { placements[i].title = window.title }
            placements[i].appName = window.appName
            if now.timeIntervalSince(placements[i].lastSeen) > Self.lastSeenGranularity {
                placements[i].lastSeen = now
            }
            lastObserved[window.windowID] = key
        }

        let live = Set(windows.map(\.windowID))
        placements.removeAll { !live.contains($0.windowID) && now.timeIntervalSince($0.lastSeen) > Self.retention }
        // A window out of sight while macOS rearranges may be moved by it: where it was is forgotten,
        // so its return elsewhere leaves it displaced.
        let remembered = trusted ? Set(placements.map(\.windowID)) : live
        lastObserved = lastObserved.filter { remembered.contains($0.key) }
    }

    public func home(ofWindow windowID: Int) -> WorkspaceKey? {
        placements.first { $0.windowID == windowID }?.home
    }

    /// Assigns a window to a workspace regardless of where it currently is.
    public mutating func rehome(windowID: Int, to key: WorkspaceKey) {
        guard let i = placements.firstIndex(where: { $0.windowID == windowID }) else { return }
        placements[i].home = key
        unconfirmedRehomes[windowID] = nil
    }

    /// Declares the current arrangement to be the intended one.
    public mutating func acceptCurrentLayout(_ windows: [LiveWindow], layout: DesktopLayout) {
        for window in windows {
            guard let key = layout.key(ofSpace: window.spaceID),
                  let i = placements.firstIndex(where: { $0.windowID == window.windowID }) else { continue }
            placements[i].home = key
            placements[i].frame = window.frame
            unconfirmedRehomes[window.windowID] = nil
        }
    }

    public func displaced(_ windows: [LiveWindow], layout: DesktopLayout) -> [Displacement] {
        windows.compactMap { window in
            guard let placement = placements.first(where: { $0.windowID == window.windowID }),
                  let key = layout.key(ofSpace: window.spaceID), key != placement.home else { return nil }
            return Displacement(window: window, home: placement.home, homeFrame: placement.frame)
        }
    }

    public func windowCount(on key: WorkspaceKey, among windows: [LiveWindow], layout: DesktopLayout) -> Int {
        windows.filter { layout.key(ofSpace: $0.spaceID) == key }.count
    }
}
