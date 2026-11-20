import CoreGraphics
import Foundation

/// Observes right-clicks anywhere on screen without intercepting them.
/// An event tap is used because, while Mission Control is open, AppKit's global event monitors receive nothing.
final class RightClickListener {
    private let onClick: (CGPoint) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// nil when the tap cannot be created, which means the Accessibility permission is missing.
    /// - Parameter onClick: called on the main thread with the click position in global top-left coordinates.
    init?(onClick: @escaping (CGPoint) -> Void) {
        self.onClick = onClick
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                          eventsOfInterest: CGEventMask(1 << CGEventType.rightMouseDown.rawValue), callback: { _, type, event, context in
            if let context {
                let listener = Unmanaged<RightClickListener>.fromOpaque(context).takeUnretainedValue()
                if type == .rightMouseDown {
                    listener.onClick(event.location)
                } else if let tap = listener.tap {
                    // macOS switches a tap off when it is slow to respond or on user input bursts.
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return nil }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
    }
}
