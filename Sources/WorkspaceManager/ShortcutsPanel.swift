import AppKit
import MacDesktop

/// Help window listing the shortcuts as currently configured.
final class ShortcutsPanel: NSObject {
    private var panel: NSPanel?

    func show(_ settings: Settings) {
        panel?.close()
        let grid = NSGridView(views: Self.rows(for: settings).map { action, shortcut in
            let key = NSTextField(labelWithString: shortcut)
            key.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            return [key, NSTextField(labelWithString: action)]
        })
        grid.columnSpacing = 20
        grid.rowSpacing = 8
        grid.column(at: 0).xPlacement = .trailing

        let note = NSTextField(wrappingLabelWithString: "Shortcuts are edited in config.json and applied when the app restarts.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 11)
        note.preferredMaxLayoutWidth = 420

        let edit = NSButton(title: "Edit Shortcuts…", target: self, action: #selector(editShortcuts))

        let stack = NSStackView(views: [grid, note, edit])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Workspace Manager Shortcuts"
        panel.isReleasedWhenClosed = false
        // A menu-bar app is rarely the active app; a default panel would hide itself at once.
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentView = stack
        panel.setContentSize(stack.fittingSize)
        panel.center()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Opens config.json in the default editor for JSON files.
    @objc private func editShortcuts() {
        NSWorkspace.shared.open(Settings.file)
        panel?.close()
    }

    /// Action and shortcut pairs; an unusable setting is shown as such instead of being hidden.
    static func rows(for settings: Settings) -> [(action: String, shortcut: String)] {
        func key(_ text: String) -> String {
            if text.isEmpty { return "disabled" }
            return KeyStroke(text)?.symbols ?? "invalid: \(text)"
        }
        let click = KeyStroke.Modifiers(settings.titleBarMenu.modifiers).map { "\($0.symbols)Right-click" } ?? "invalid: \(settings.titleBarMenu.modifiers)"
        return [
            ("Go to a workspace", key(settings.shortcuts.switchWorkspace)),
            ("Send the focused window to a workspace", key(settings.shortcuts.sendWindow)),
            ("Send a window to a workspace, on its title bar", click),
            ("Restore displaced windows", key(settings.shortcuts.restoreWindows)),
            ("Pick one of the first nine workspaces in a list", "1 – 9"),
            ("Move in a list, confirm, cancel", "↑ ↓  ↩  ⎋"),
        ]
    }
}
