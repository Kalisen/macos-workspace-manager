import AppKit
import Workspaces

/// Lists the application windows of every Space, visible or not.
public enum WindowReader {
    private static let minimumSide = 100.0

    /// Titles of windows on hidden Spaces are only readable with the Screen Recording permission.
    public static var canReadTitles: Bool { CGPreflightScreenCaptureAccess() }

    public static func windows(in layout: DesktopLayout) -> [LiveWindow] {
        guard let raw = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var apps: [pid_t: NSRunningApplication?] = [:]
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return raw.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  let windowID = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  bounds.width >= minimumSide, bounds.height >= minimumSide,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            // Windows on several Spaces are sticky; windows on none are hidden or minimized.
            let spaces = SpaceReader.spaceIDs(ofWindow: windowID)
            guard spaces.count == 1, layout.key(ofSpace: spaces[0]) != nil else { return nil }
            if apps[pid] == nil { apps[pid] = .some(NSRunningApplication(processIdentifier: pid)) }
            guard let app = apps[pid] ?? nil, app.activationPolicy == .regular, let bundleID = app.bundleIdentifier else { return nil }
            return LiveWindow(
                windowID: windowID, pid: pid, bundleID: bundleID,
                appName: app.localizedName ?? info[kCGWindowOwnerName as String] as? String ?? bundleID,
                title: info[kCGWindowName as String] as? String ?? "",
                spaceID: spaces[0],
                frame: WindowFrame(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height))
        }
    }

    /// Topmost application window under a point given in global top-left coordinates.
    public static func windowID(at point: CGPoint) -> (windowID: Int, bounds: CGRect)? {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in raw {
            guard let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo), bounds.contains(point),
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let windowID = info[kCGWindowNumber as String] as? Int else { continue }
            // Anything above the application layer (menus, overlays, the Dock) owns the click.
            return layer == 0 ? (windowID, bounds) : nil
        }
        return nil
    }

    /// Window that has keyboard focus in the frontmost app.
    public static func focusedWindowID() -> Int? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        var windowID: UInt32 = 0
        guard _AXUIElementGetWindow(value as! AXUIElement, &windowID) == .success else { return nil }
        return Int(windowID)
    }
}
