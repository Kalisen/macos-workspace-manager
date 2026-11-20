import Carbon
import MacDesktop

/// Global keyboard shortcuts, registered with the system so they need no permission.
final class HotKeys {
    private var handlers: [UInt32: () -> Void] = [:]
    private var references: [EventHotKeyRef] = []
    private static let signature: OSType = 0x574B_5350 // "WKSP"

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            if status == noErr {
                Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue().handlers[id.id]?()
            }
            return status
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// False when the system refuses the shortcut, typically because another app owns it.
    func register(_ stroke: KeyStroke, handler: @escaping () -> Void) -> Bool {
        var modifiers = 0
        if stroke.modifiers.contains(.command) { modifiers |= cmdKey }
        if stroke.modifiers.contains(.shift) { modifiers |= shiftKey }
        if stroke.modifiers.contains(.option) { modifiers |= optionKey }
        if stroke.modifiers.contains(.control) { modifiers |= controlKey }
        let id = UInt32(handlers.count + 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(stroke.keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return false }
        handlers[id] = handler
        references.append(reference)
        return true
    }
}
