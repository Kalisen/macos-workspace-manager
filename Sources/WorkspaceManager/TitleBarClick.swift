import CoreGraphics
import Foundation
import MacDesktop

/// Detects modifier + right-click on the title bar of any window and reports the window.
/// macOS does not let an app add items to another app's own title-bar menu, so the click is intercepted instead.
final class TitleBarClick {
    private let modifiers: KeyStroke.Modifiers
    private let height: Double
    private let onClick: (Int) -> Void
    private var tap: CFMachPort?
    private var swallowRelease = false

    /// nil when the event tap cannot be created, which means the Accessibility permission is missing.
    init?(modifiers: KeyStroke.Modifiers, height: Double, onClick: @escaping (Int) -> Void) {
        self.modifiers = modifiers
        self.height = height
        self.onClick = onClick
        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue | 1 << CGEventType.rightMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let this = Unmanaged<TitleBarClick>.fromOpaque(context).takeUnretainedValue()
            return this.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return nil }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    /// True when the event is consumed.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .rightMouseDown:
            guard KeyStroke.Modifiers(event.flags) == modifiers,
                  let hit = WindowReader.windowID(at: event.location),
                  event.location.y - hit.bounds.minY <= height else { return false }
            swallowRelease = true
            let windowID = hit.windowID
            DispatchQueue.main.async { self.onClick(windowID) }
            return true
        case .rightMouseUp:
            defer { swallowRelease = false }
            return swallowRelease
        default:
            return false
        }
    }
}
