import CoreGraphics

/// A key with modifiers, e.g. "ctrl+alt+space".
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public let modifiers: Modifiers

    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let shift = Modifiers(rawValue: 4)
        public static let command = Modifiers(rawValue: 8)

        /// Parses "ctrl+alt"; nil when a part is not a modifier.
        public init?(_ text: String) {
            self.init(rawValue: 0)
            for part in text.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                guard let modifier = Self.names[part] else { return nil }
                insert(modifier)
            }
        }

        public init(_ flags: CGEventFlags) {
            self.init(rawValue: 0)
            if flags.contains(.maskControl) { insert(.control) }
            if flags.contains(.maskAlternate) { insert(.option) }
            if flags.contains(.maskShift) { insert(.shift) }
            if flags.contains(.maskCommand) { insert(.command) }
        }

        /// Standard macOS glyphs, e.g. "⌃⌥".
        public var symbols: String {
            (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "") + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
        }

        static let names: [String: Modifiers] = [
            "ctrl": .control, "control": .control, "alt": .option, "option": .option, "opt": .option,
            "shift": .shift, "cmd": .command, "command": .command,
        ]
    }

    public init(keyCode: CGKeyCode, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Parses "ctrl+alt+space"; nil when the key is unknown or missing.
    public init?(_ text: String) {
        let parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let key = parts.last, let keyCode = Self.keyCodes[key],
              let modifiers = Modifiers(parts.dropLast().joined(separator: "+")) else { return nil }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    /// Human-readable form, e.g. "⌃⌥Space".
    public var symbols: String {
        let key = Self.keyCodes.first { $0.value == keyCode }?.key ?? "key \(keyCode)"
        let glyphs = ["left": "←", "right": "→", "up": "↑", "down": "↓", "return": "↩", "tab": "⇥", "escape": "⎋"]
        return modifiers.symbols + (glyphs[key] ?? (key.count == 1 ? key.uppercased() : key.capitalized))
    }

    /// ANSI virtual key codes.
    static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26,
        "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "return": 36, "tab": 48, "space": 49, "escape": 53, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111,
    ]
}
