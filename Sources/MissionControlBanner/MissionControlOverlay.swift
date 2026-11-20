import AppKit

/// Shows the current workspace name in large characters at the centre of each display while Mission Control is open.
///
/// Self-contained: it depends on nothing else in the app, and if macOS stops cooperating the labels
/// simply do not appear.
public final class MissionControlOverlay {
    private static let watchdogInterval = 1.0

    private let watcher = MissionControlWatcher()
    private let banner = WorkspaceBanner()
    private let labels: () -> [WorkspaceLabel]
    private var watchdog: Timer?

    /// Reports a failure to follow the Dock after it relaunched; the overlay stays off until restarted.
    public var onFailure: ((Error) -> Void)?

    /// - Parameter labels: called on the main thread each time the labels are drawn.
    public init(labels: @escaping () -> [WorkspaceLabel]) {
        self.labels = labels
    }

    public var isShowing: Bool { banner.isShowing }
    public var windowNumbers: [Int] { banner.windowNumbers }

    public func start() throws {
        watcher.onOpen = { [weak self] in self?.show() }
        watcher.onClose = { [weak self] in self?.hide() }
        watcher.onAttachFailure = { [weak self] in self?.onFailure?($0) }
        try watcher.start()
    }

    /// Redraws the labels if they are showing, e.g. after the user switched desktop inside Mission Control.
    public func refresh() {
        if banner.isShowing { banner.show(labels()) }
    }

    private func show() {
        banner.show(labels())
        // A missed "closed" signal must not leave the labels on screen.
        watchdog?.invalidate()
        let timer = Timer(timeInterval: Self.watchdogInterval, repeats: true) { [weak self] _ in
            guard let self, !self.watcher.isOpen else { return }
            self.hide()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func hide() {
        watchdog?.invalidate()
        watchdog = nil
        banner.hide()
    }
}
