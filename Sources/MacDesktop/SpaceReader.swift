import AppKit
import Workspaces

public enum SpaceReaderError: Error, CustomStringConvertible {
    case unexpectedShape(String)
    case noBootSession(errno: Int32)

    public var description: String {
        switch self {
        case .unexpectedShape(let detail): "macOS returned Spaces data in an unknown shape: \(detail)"
        case .noBootSession(let code): "macOS did not provide the boot session identifier (errno \(code))"
        }
    }
}

/// Reads the Mission Control arrangement from the window server.
public enum SpaceReader {
    /// Key of the first desktop of the main display, which macOS leaves without a UUID.
    static let primaryKey = "primary"
    private static let allSpaces: Int32 = 7
    private static let fullscreenType = 4

    public static func layout() throws -> DesktopLayout {
        guard let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] else {
            throw SpaceReaderError.unexpectedShape("display list")
        }
        return DesktopLayout(displays: try raw.map { display in
            guard let id = display["Display Identifier"] as? String,
                  let current = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int,
                  let spaces = display["Spaces"] as? [[String: Any]] else {
                throw SpaceReaderError.unexpectedShape("display entry keys \(display.keys.sorted())")
            }
            let desktops = try spaces.map { space in
                guard let spaceID = space["ManagedSpaceID"] as? Int, let uuid = space["uuid"] as? String else {
                    throw SpaceReaderError.unexpectedShape("space entry keys \(space.keys.sorted())")
                }
                return Desktop(spaceID: spaceID, key: uuid.isEmpty ? primaryKey : uuid,
                               isFullscreen: (space["type"] as? Int) == fullscreenType)
            }
            return Display(id: id, desktops: desktops, currentSpaceID: current)
        })
    }

    public static func spaceIDs(ofWindow windowID: Int) -> [Int] {
        CGSCopySpacesForWindows(CGSMainConnectionID(), allSpaces, [windowID] as CFArray) as? [Int] ?? []
    }

    /// Bounds of a display in global top-left coordinates, the system used by window frames and mouse events.
    public static func bounds(ofDisplay id: String) -> CGRect? {
        if id == "Main" { return CGDisplayBounds(CGMainDisplayID()) }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { continue }
            if CFUUIDCreateString(nil, uuid) as String == id { return CGDisplayBounds(number) }
        }
        return nil
    }

    /// Identifier of the display holding the key window, as used in `DesktopLayout`.
    public static func activeDisplayID(in layout: DesktopLayout) -> String? {
        guard let number = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return layout.displays.first?.id }
        let id = CFUUIDCreateString(nil, uuid) as String
        return layout.displays.contains { $0.id == id } ? id : layout.displays.first?.id
    }

    /// Changes at every boot; window IDs are only comparable within one boot session.
    /// The kernel's boot time is not usable for this: it shifts when the clock is adjusted.
    public static func bootSession() throws -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1 else {
            throw SpaceReaderError.noBootSession(errno: errno)
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else {
            throw SpaceReaderError.noBootSession(errno: errno)
        }
        return String(cString: buffer)
    }
}
