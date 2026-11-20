/// Stable identity of a workspace: the UUID macOS gives the underlying Space.
/// It survives reboots and display reconnection, unlike the numeric Space ID.
public typealias WorkspaceKey = String

/// One macOS Space as currently arranged in Mission Control.
public struct Desktop: Equatable, Sendable {
    public let spaceID: Int
    public let key: WorkspaceKey
    /// Fullscreen and tiled Spaces cannot host arbitrary windows.
    public let isFullscreen: Bool

    public init(spaceID: Int, key: WorkspaceKey, isFullscreen: Bool = false) {
        self.spaceID = spaceID
        self.key = key
        self.isFullscreen = isFullscreen
    }
}

public struct Display: Equatable, Sendable {
    public let id: String
    /// Mission Control order, left to right, fullscreen Spaces included.
    public let desktops: [Desktop]
    public let currentSpaceID: Int

    public init(id: String, desktops: [Desktop], currentSpaceID: Int) {
        self.id = id
        self.desktops = desktops
        self.currentSpaceID = currentSpaceID
    }
}

public struct DesktopLayout: Equatable, Sendable {
    public let displays: [Display]

    public init(displays: [Display]) {
        self.displays = displays
    }

    /// Desktops that can host windows, in Mission Control order across displays.
    public var workspaces: [Desktop] {
        displays.flatMap { $0.desktops.filter { !$0.isFullscreen } }
    }

    public func display(ofSpace spaceID: Int) -> Display? {
        displays.first { $0.desktops.contains { $0.spaceID == spaceID } }
    }

    public func desktop(spaceID: Int) -> Desktop? {
        displays.lazy.flatMap(\.desktops).first { $0.spaceID == spaceID }
    }

    public func desktop(key: WorkspaceKey) -> Desktop? {
        workspaces.first { $0.key == key }
    }

    public func key(ofSpace spaceID: Int) -> WorkspaceKey? {
        guard let desktop = desktop(spaceID: spaceID), !desktop.isFullscreen else { return nil }
        return desktop.key
    }

    /// 1-based position among workspaces, matching the "Desktop N" numbering of Mission Control.
    public func ordinal(of key: WorkspaceKey) -> Int? {
        workspaces.firstIndex { $0.key == key }.map { $0 + 1 }
    }

    public func isVisible(spaceID: Int) -> Bool {
        displays.contains { $0.currentSpaceID == spaceID }
    }

    /// Signed number of "move one Space right" steps between two Spaces of the same display.
    public func steps(from: Int, to: Int) -> Int? {
        guard let display = display(ofSpace: from),
              let a = display.desktops.firstIndex(where: { $0.spaceID == from }),
              let b = display.desktops.firstIndex(where: { $0.spaceID == to }) else { return nil }
        return b - a
    }
}
