import CoreGraphics
import Foundation

/// Posts mouse and keyboard events as if they came from hardware.
enum SyntheticInput {
    private static let source = CGEventSource(stateID: .hidSystemState)

    /// Modifiers are cleared: keys physically held by the user (e.g. a dictation hotkey)
    /// would otherwise turn the click into a Control-click.
    static func mouse(_ type: CGEventType, at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    static func press(_ shortcut: SystemShortcut) {
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: keyDown) else { return }
            event.flags = shortcut.flags
            event.post(tap: .cghidEventTap)
            pause(0.03)
        }
    }

    static var cursor: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    static func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Polls until the condition holds; false on timeout.
    static func wait(upTo timeout: TimeInterval, every interval: TimeInterval = 0.02, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            pause(interval)
        }
        return true
    }
}
