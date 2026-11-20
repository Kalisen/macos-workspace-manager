import AppKit
import Workspaces

public enum WindowMoveError: Error, CustomStringConvertible {
    case accessibilityDenied
    case windowGone
    case notReachable
    case noTitleBar
    case notGrabbed
    case notMoved(current: [Int])

    public var description: String {
        switch self {
        case .accessibilityDenied: "Accessibility permission is missing"
        case .windowGone: "the window no longer exists"
        case .notReachable: "the window is not exposed by its app"
        case .noTitleBar: "the window has no standard title bar buttons to drag it by"
        case .notGrabbed: "the window did not follow the pointer"
        case .notMoved(let current): "the window ended on desktop \(current) instead of its target"
        }
    }
}

/// Moves another app's window to a Space.
///
/// macOS offers no working call for this with SIP enabled, so the window is dragged like a user would:
/// press the mouse on its title bar, switch Space with the Mission Control shortcuts, release.
/// Each stage is verified against the window server.
public struct WindowMover {
    private static let grabTimeout = 1.0
    private static let grabAttempts = 3
    /// Window frames read from the window list and from the app differ by a point depending on focus.
    static let frameTolerance: CGFloat = 2

    let switcher: SpaceSwitcher

    public init(switcher: SpaceSwitcher = SpaceSwitcher()) {
        self.switcher = switcher
    }

    /// - Parameter frame: where to put the window on the target Space; its current frame when nil.
    public func move(_ window: LiveWindow, toSpace target: Int, frame: WindowFrame? = nil) throws {
        guard AXIsProcessTrusted() else { throw WindowMoveError.accessibilityDenied }
        guard let start = SpaceReader.spaceIDs(ofWindow: window.windowID).first else { throw WindowMoveError.windowGone }
        if start == target { return }

        // A window can only be grabbed on a visible Space.
        try switcher.go(toSpace: start)
        var element: AXUIElement?
        _ = SyntheticInput.wait(upTo: 1.5, every: 0.1) {
            element = Self.element(of: window)
            return element != nil
        }
        guard let element else { throw WindowMoveError.notReachable }
        let original = try Self.frame(of: element)

        var layout = try SpaceReader.layout()
        guard let targetDisplay = layout.display(ofSpace: target) else { throw SpaceSwitchError.unknownSpace(target) }
        if layout.display(ofSpace: start)?.id != targetDisplay.id, let bounds = SpaceReader.bounds(ofDisplay: targetDisplay.id) {
            // Positioning a window on another display hands it to that display's current Space.
            Self.setFrame(element, CGRect(x: bounds.midX - original.width / 2, y: bounds.minY + 60, width: original.width, height: original.height))
            _ = SyntheticInput.wait(upTo: 1.5) { SpaceReader.spaceIDs(ofWindow: window.windowID) == [targetDisplay.currentSpaceID] }
            layout = try SpaceReader.layout()
        }

        if SpaceReader.spaceIDs(ofWindow: window.windowID) != [target] {
            try carry(element, pid: window.pid) { try switcher.go(toSpace: target, carrying: true) }
        }

        let arrived = SyntheticInput.wait(upTo: 1) { SpaceReader.spaceIDs(ofWindow: window.windowID) == [target] }
        guard arrived else { throw WindowMoveError.notMoved(current: SpaceReader.spaceIDs(ofWindow: window.windowID)) }
        let sameDisplay = layout.display(ofSpace: start)?.id == targetDisplay.id
        if let frame {
            Self.setFrame(element, CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height))
        } else if sameDisplay {
            Self.setFrame(element, original)
        }
    }

    /// Holds the window by its title bar while `travel` switches Space.
    private func carry(_ element: AXUIElement, pid: pid_t, travel: () throws -> Void) throws {
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        SyntheticInput.pause(0.25)

        let origin = try Self.frame(of: element).origin
        let grip = try Self.grip(of: element)
        let cursor = SyntheticInput.cursor
        // Keep the physical mouse from pulling the pointer away mid-drag.
        CGAssociateMouseAndMouseCursorPosition(0)
        defer {
            CGAssociateMouseAndMouseCursorPosition(1)
            CGWarpMouseCursorPosition(cursor)
        }

        var grabbed = false
        for _ in 0..<Self.grabAttempts where !grabbed {
            SyntheticInput.mouse(.mouseMoved, at: grip)
            SyntheticInput.pause(0.06)
            SyntheticInput.mouse(.leftMouseDown, at: grip)
            SyntheticInput.pause(0.06)
            var nudge = 0.0
            var windowGone = false
            grabbed = SyntheticInput.wait(upTo: Self.grabTimeout, every: 0.025) {
                nudge = min(nudge + 1, 10)
                SyntheticInput.mouse(.leftMouseDragged, at: CGPoint(x: grip.x + nudge, y: grip.y + nudge))
                guard let now = Self.rect(of: element) else { windowGone = true; return true }
                return now.origin != origin
            }
            if windowGone {
                SyntheticInput.mouse(.leftMouseUp, at: grip)
                throw WindowMoveError.windowGone
            }
            if !grabbed {
                SyntheticInput.mouse(.leftMouseUp, at: grip)
                SyntheticInput.pause(0.6)
            }
        }
        guard grabbed else { throw WindowMoveError.notGrabbed }
        defer {
            SyntheticInput.mouse(.leftMouseDragged, at: grip)
            SyntheticInput.pause(0.06)
            SyntheticInput.mouse(.leftMouseUp, at: grip)
            SyntheticInput.pause(0.15)
        }
        try travel()
    }

    /// A point of the title bar that is safe to drag in any app: the gap between the close and minimize
    /// buttons. Elsewhere, apps with tabs in the title bar (browsers, terminals) would tear a tab off.
    private static func grip(of window: AXUIElement) throws -> CGPoint {
        guard let close = button(kAXCloseButtonAttribute, of: window), let minimize = button(kAXMinimizeButtonAttribute, of: window),
              minimize.minX > close.maxX else { throw WindowMoveError.noTitleBar }
        return CGPoint(x: (close.maxX + minimize.minX) / 2, y: close.midY)
    }

    private static func button(_ attribute: String, of window: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return rect(of: value as! AXUIElement)
    }

    private static func element(of window: LiveWindow) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(window.pid), kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return nil }
        return elements.first {
            var id: UInt32 = 0
            return _AXUIElementGetWindow($0, &id) == .success && Int(id) == window.windowID
        }
    }

    private static func frame(of element: AXUIElement) throws -> CGRect {
        guard let rect = rect(of: element) else { throw WindowMoveError.windowGone }
        return rect
    }

    /// nil when the element no longer exists.
    private static func rect(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }

    /// Apps can ignore a frame change that arrives while the window is still settling on a new display
    /// or Space, so the frame is re-applied until the window reports it.
    private static func setFrame(_ element: AXUIElement, _ frame: CGRect) {
        var origin = frame.origin, size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let extent = AXValueCreate(.cgSize, &size) else { return }
        for _ in 0..<5 {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, extent)
            SyntheticInput.pause(0.1)
            guard let now = rect(of: element) else { return }
            if abs(now.minX - frame.minX) <= frameTolerance, abs(now.minY - frame.minY) <= frameTolerance { return }
        }
    }
}
