import AppKit
import MacDesktop
import MissionControlBanner
import os
import ServiceManagement
import Workspaces

/// Menu-bar app: names workspaces, tracks which workspace each window belongs to, and puts windows back.
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let observationInterval = 2.0

    private let log = Logger(subsystem: "workspace-manager", category: "app")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let work = DispatchQueue(label: "workspace-manager.moves")
    private let hotKeys = HotKeys()
    private var titleBarClick: TitleBarClick?
    private let shortcutsPanel = ShortcutsPanel()
    private var missionControlOverlay: MissionControlOverlay?
    private var missionControlOverlayFailed = false

    private var settings = Settings()
    private var state = WorkspaceState()
    private var layout = DesktopLayout(displays: [])
    private var windows: [LiveWindow] = []
    private var settling = SettlingPeriod()
    private var moving = false
    private var problems: [String] = []
    private var lastReadFailure: String?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()
        loadState()
        requestPermissions()
        registerShortcuts()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        settling.systemRearranged(at: Date())
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemRearranged), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemRearranged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let timer = Timer(timeInterval: Self.observationInterval, repeats: true) { [weak self] _ in self?.observe() }
        RunLoop.main.add(timer, forMode: .common)
        observe()
    }

    private func loadSettings() {
        do {
            settings = try Settings.load()
        } catch {
            log.error("Using default settings, \(Settings.file.path, privacy: .public) is unreadable: \(String(describing: error), privacy: .public)")
            problems.append("config.json is invalid; defaults are in use")
        }
    }

    private func loadState() {
        do {
            state = try StateStore.load()
        } catch {
            log.error("Saved state is unreadable: \(String(describing: error), privacy: .public)")
            do {
                let kept = try StateStore.quarantine()
                problems.append("Saved workspaces were unreadable and set aside as \(kept.lastPathComponent)")
            } catch {
                log.error("Could not set the unreadable state aside: \(String(describing: error), privacy: .public)")
                problems.append("Saved workspaces are unreadable")
            }
        }
    }

    private func requestPermissions() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(prompt) {
            log.warning("Accessibility permission missing: windows cannot be moved")
        }
        if !WindowReader.canReadTitles && !CGRequestScreenCaptureAccess() {
            log.warning("Screen Recording permission missing: window titles unavailable, windows cannot be told apart after a restart")
        }
    }

    private func registerShortcuts() {
        let bindings: [(String, String, () -> Void)] = [
            ("switchWorkspace", settings.shortcuts.switchWorkspace, { [weak self] in self?.showSwitcher() }),
            ("sendWindow", settings.shortcuts.sendWindow, { [weak self] in self?.showSendMenu(for: WindowReader.focusedWindowID()) }),
            ("restoreWindows", settings.shortcuts.restoreWindows, { [weak self] in self?.restoreDisplaced() }),
        ]
        for (name, text, handler) in bindings where !text.isEmpty {
            guard let stroke = KeyStroke(text) else {
                log.error("Shortcut \(name, privacy: .public) is not valid: \(text, privacy: .public)")
                problems.append("Shortcut \(name) \"\(text)\" is not valid")
                continue
            }
            if !hotKeys.register(stroke, handler: handler) {
                log.error("Shortcut \(name, privacy: .public) \(text, privacy: .public) was refused by macOS")
                problems.append("Shortcut \(name) \"\(text)\" is taken by another app")
            }
        }
        if KeyStroke.Modifiers(settings.titleBarMenu.modifiers) == nil {
            log.error("titleBarMenu.modifiers is not valid: \(self.settings.titleBarMenu.modifiers, privacy: .public)")
            problems.append("titleBarMenu.modifiers \"\(settings.titleBarMenu.modifiers)\" is not valid")
        }
        watchTitleBarClicks()
    }

    /// Needs the Accessibility permission; retried on each observation until it is granted.
    private func watchTitleBarClicks() {
        guard titleBarClick == nil, AXIsProcessTrusted(), let modifiers = KeyStroke.Modifiers(settings.titleBarMenu.modifiers) else { return }
        titleBarClick = TitleBarClick(modifiers: modifiers, height: settings.titleBarMenu.height) { [weak self] windowID in
            self?.showSendMenu(for: windowID)
        }
        if titleBarClick != nil { log.info("Title-bar menu active") }
    }

    // MARK: Observation

    @objc private func systemRearranged() {
        settling.systemRearranged(at: Date())
    }

    @objc private func spaceChanged() {
        observe()
        missionControlOverlay?.refresh()
    }

    /// Optional feature: a failure is logged once and leaves the rest of the app untouched.
    /// Needs the Accessibility permission; retried on each observation until it is granted.
    private func startMissionControlOverlay() {
        guard settings.missionControlBanner.enabled, missionControlOverlay == nil, !missionControlOverlayFailed, AXIsProcessTrusted() else { return }
        let overlay = MissionControlOverlay(labelsDesktops: settings.missionControlBanner.desktopLabels) { [weak self] in self?.workspaceLabels() ?? [] }
        overlay.onFailure = { [weak self] error in
            self?.log.warning("Mission Control banner stopped: \(String(describing: error), privacy: .public)")
        }
        do {
            try overlay.start()
            missionControlOverlay = overlay
            log.info("Mission Control banner active")
        } catch {
            missionControlOverlayFailed = true
            log.warning("Mission Control banner unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    /// Per display: the name of the workspace showing, and the custom names of its desktops.
    private func workspaceLabels() -> [WorkspaceLabel] {
        observe()
        return layout.displays.compactMap { display in
            guard let bounds = SpaceReader.bounds(ofDisplay: display.id) else { return nil }
            // A fullscreen Space is not a workspace: no large name, the desktops are still labelled.
            let current = layout.key(ofSpace: display.currentSpaceID).map { state.names.name(of: $0, in: layout) } ?? ""
            let custom = display.desktops.map { $0.isFullscreen ? nil : state.names.customName(of: $0.key) }
            return WorkspaceLabel(text: current, displayBounds: bounds, desktopNames: custom)
        }
    }

    private func observe() {
        guard !moving else { return }
        watchTitleBarClicks()
        startMissionControlOverlay()
        do {
            layout = try SpaceReader.layout()
            lastReadFailure = nil
        } catch {
            let failure = String(describing: error)
            if failure != lastReadFailure {
                log.error("Cannot read desktops: \(failure, privacy: .public)")
                lastReadFailure = failure
            }
            statusItem.button?.title = "⚠︎"
            return
        }
        windows = WindowReader.windows(in: layout)
        let before = state
        state.book.observe(windows, layout: layout, session: SpaceReader.bootSession(), trusted: settling.isOver(at: Date()), now: Date())
        if state != before { save() }
        updateTitle()
    }

    private func save() {
        do {
            try StateStore.save(state)
        } catch {
            log.error("Cannot save state: \(String(describing: error), privacy: .public)")
        }
    }

    private var activeDisplay: Display? {
        let id = SpaceReader.activeDisplayID(in: layout)
        return layout.displays.first { $0.id == id }
    }

    private var displaced: [Displacement] {
        state.book.displaced(windows, layout: layout)
    }

    private func updateTitle() {
        var title = "—"
        if let display = activeDisplay, let key = layout.key(ofSpace: display.currentSpaceID) {
            title = state.names.name(of: key, in: layout)
        } else if activeDisplay != nil {
            title = "Fullscreen"
        }
        let count = displaced.count
        statusItem.button?.title = count > 0 ? "\(title) ⚠︎\(count)" : title
    }

    // MARK: Menus

    func menuNeedsUpdate(_ menu: NSMenu) {
        observe()
        menu.removeAllItems()
        addWorkspaces(to: menu) { [weak self] desktop in self?.go(to: desktop) }
        menu.addItem(.separator())
        menu.addItem(ActionItem("Rename Current Desktop…") { [weak self] in self?.renameCurrent() })
        let focused = WindowReader.focusedWindowID()
        if let window = windows.first(where: { $0.windowID == focused }) {
            let send = NSMenuItem(title: "Send \(window.appName) Window To", action: nil, keyEquivalent: "")
            send.submenu = NSMenu()
            addWorkspaces(to: send.submenu!, home: state.book.home(ofWindow: window.windowID)) { [weak self] desktop in
                self?.send(window.windowID, to: desktop)
            }
            menu.addItem(send)
        }
        menu.addItem(.separator())
        let displaced = displaced
        if displaced.isEmpty {
            menu.addNote("All windows are on their desktop")
        } else {
            menu.addItem(ActionItem("Restore \(displaced.count) Displaced Window\(displaced.count == 1 ? "" : "s")") { [weak self] in self?.restoreDisplaced() })
            menu.addItem(ActionItem("Keep Current Layout") { [weak self] in self?.keepCurrentLayout() })
            for item in displaced.prefix(12) {
                let title = item.window.title.isEmpty ? item.window.appName : "\(item.window.appName) — \(item.window.title.prefix(40))"
                menu.addNote("   \(title) → \(state.names.name(of: item.home, in: layout))")
            }
        }
        var notes = problems
        if !AXIsProcessTrusted() { notes.append("Grant Accessibility permission to move windows") }
        if !WindowReader.canReadTitles { notes.append("Grant Screen Recording permission to recognise windows after a restart") }
        if !notes.isEmpty {
            menu.addItem(.separator())
            notes.forEach { menu.addNote("⚠︎ \($0)") }
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem("Shortcuts…") { [weak self] in
            guard let self else { return }
            self.shortcutsPanel.show(self.settings)
        })
        menu.addItem(ActionItem("Open Configuration") { NSWorkspace.shared.open(Settings.file) })
        // Login items are registered per app bundle; a bare binary run from a terminal has none.
        if Bundle.main.bundleIdentifier != nil {
            let item = ActionItem("Start at Login") { [weak self] in self?.toggleStartAtLogin() }
            item.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(ActionItem("Quit Workspace Manager") { NSApp.terminate(nil) })
    }

    /// Lists workspaces by display; digits 1–9 select the first nine.
    private func addWorkspaces(to menu: NSMenu, home: WorkspaceKey? = nil, action: @escaping (Desktop) -> Void) {
        for (index, display) in layout.displays.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for desktop in display.desktops where !desktop.isFullscreen {
                let ordinal = layout.ordinal(of: desktop.key) ?? 0
                let count = state.book.windowCount(on: desktop.key, among: windows, layout: layout)
                let name = state.names.name(of: desktop.key, in: layout)
                let item = ActionItem(count > 0 ? "\(name)  (\(count))" : name, key: ordinal <= 9 ? String(ordinal) : "") { action(desktop) }
                item.state = desktop.key == home ?? layout.key(ofSpace: display.currentSpaceID) ? .on : .off
                menu.addItem(item)
            }
        }
    }

    private func popUp(_ menu: NSMenu, at point: NSPoint) {
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    private func showSwitcher() {
        observe()
        let menu = NSMenu(title: "Go to Desktop")
        menu.addNote("Go to desktop")
        addWorkspaces(to: menu) { [weak self] desktop in self?.go(to: desktop) }
        let screen = NSScreen.main?.frame ?? .zero
        popUp(menu, at: NSPoint(x: screen.midX - 100, y: screen.midY + CGFloat(menu.numberOfItems) * 11))
    }

    private func showSendMenu(for windowID: Int?) {
        observe()
        guard let window = windows.first(where: { $0.windowID == windowID }) else {
            log.debug("Send menu skipped: no tracked window under the request")
            return
        }
        let menu = NSMenu(title: "Send to Desktop")
        menu.addNote("Send \(window.appName) window to")
        addWorkspaces(to: menu, home: state.book.home(ofWindow: window.windowID)) { [weak self] desktop in
            self?.send(window.windowID, to: desktop)
        }
        popUp(menu, at: NSEvent.mouseLocation)
    }

    // MARK: Actions

    private func renameCurrent() {
        guard let display = activeDisplay, let key = layout.key(ofSpace: display.currentSpaceID) else { return }
        let alert = NSAlert()
        alert.messageText = "Name this desktop"
        alert.informativeText = "Leave empty to go back to the default name."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = state.names.name(of: key, in: layout)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        state.names.rename(key, to: field.stringValue)
        save()
        updateTitle()
    }

    private func go(to desktop: Desktop) {
        work.async {
            do {
                try SpaceSwitcher().go(toSpace: desktop.spaceID)
            } catch {
                self.log.error("Cannot switch desktop: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async { self.report("Could not switch desktop", ["\(error)"]) }
            }
        }
    }

    private func send(_ windowID: Int, to desktop: Desktop) {
        state.book.rehome(windowID: windowID, to: desktop.key)
        save()
        relocate(displaced.filter { $0.window.windowID == windowID })
    }

    private func restoreDisplaced() {
        observe()
        relocate(displaced)
    }

    private func keepCurrentLayout() {
        state.book.acceptCurrentLayout(windows, layout: layout)
        save()
        updateTitle()
    }

    private func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            log.info("Start at login is now \(SMAppService.mainApp.status == .enabled ? "on" : "off", privacy: .public)")
        } catch {
            log.error("Cannot change start at login: \(String(describing: error), privacy: .public)")
            report("Start at Login could not be changed", [error.localizedDescription])
        }
    }

    /// Moves each window to its home workspace, then returns to the desktops that were showing.
    private func relocate(_ items: [Displacement]) {
        guard !moving, !items.isEmpty else { return }
        moving = true
        statusItem.button?.title = "Moving…"
        let layout = layout, names = state.names
        let frontmost = NSWorkspace.shared.frontmostApplication
        work.async {
            let switcher = SpaceSwitcher()
            let mover = WindowMover(switcher: switcher)
            var failures: [String] = []
            for item in items {
                let label = "\(item.window.appName) → \(names.name(of: item.home, in: layout))"
                guard let home = layout.desktop(key: item.home) else {
                    self.log.warning("Not moved, home desktop no longer exists: \(label, privacy: .public)")
                    failures.append("\(label): the desktop no longer exists")
                    continue
                }
                do {
                    try mover.move(item.window, toSpace: home.spaceID, frame: item.homeFrame)
                    self.log.info("Moved \(label, privacy: .public)")
                } catch {
                    self.log.error("Move failed, \(label, privacy: .public): \(String(describing: error), privacy: .public)")
                    failures.append("\(label): \(error)")
                }
            }
            for display in layout.displays {
                do {
                    try switcher.go(toSpace: display.currentSpaceID)
                } catch {
                    self.log.warning("Could not return to the starting desktop: \(String(describing: error), privacy: .public)")
                }
            }
            DispatchQueue.main.async {
                if let frontmost, frontmost != NSRunningApplication.current { frontmost.activate() }
                self.moving = false
                self.observe()
                self.report(failures.count == 1 ? "A window could not be moved" : "\(failures.count) windows could not be moved", failures)
            }
        }
    }

    private func report(_ summary: String, _ failures: [String]) {
        guard !failures.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = summary
        alert.informativeText = failures.joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
