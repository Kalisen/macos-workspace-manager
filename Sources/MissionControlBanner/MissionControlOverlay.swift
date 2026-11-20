import AppKit

/// Shows workspace names while Mission Control is open: the current one in large characters at the centre
/// of each display, and each named desktop over its entry in the bar at the top.
///
/// Self-contained: it depends on nothing else in the app, and if macOS stops cooperating the labels
/// simply do not appear. The two kinds of label fail independently.
public final class MissionControlOverlay {
    /// How often the desktop bar is read: it expands, collapses and reorders while Mission Control is open.
    private static let trackingInterval = 0.1
    /// Names are re-read every this many readings, to follow desktops added or removed in Mission Control.
    private static let readingsPerNameRefresh = 10

    let watcher = MissionControlWatcher()
    private let banner = WorkspaceBanner()
    private let barLabels = DesktopBarLabels()
    private let labels: () -> [WorkspaceLabel]
    private let labelsDesktops: Bool
    private var current: [WorkspaceLabel] = []
    private var tracking: Timer?
    private var readings = 0

    /// Reports a failure to follow the Dock after it relaunched; the overlay stays off until restarted.
    public var onFailure: ((Error) -> Void)?

    /// - Parameters:
    ///   - labelsDesktops: also label the desktops of the bar at the top.
    ///   - labels: called on the main thread when Mission Control opens and about once a second while it is open.
    public init(labelsDesktops: Bool = true, labels: @escaping () -> [WorkspaceLabel]) {
        self.labelsDesktops = labelsDesktops
        self.labels = labels
    }

    public var isShowing: Bool { banner.isShowing }
    public var windowNumbers: [Int] { banner.windowNumbers }
    public var desktopLabelWindowNumbers: [Int] { barLabels.windowNumbers }

    public func start() throws {
        watcher.onOpen = { [weak self] in self?.show() }
        watcher.onClose = { [weak self] in self?.hide() }
        watcher.onAttachFailure = { [weak self] in self?.onFailure?($0) }
        try watcher.start()
    }

    /// Redraws the labels if they are showing, e.g. after the user switched desktop inside Mission Control.
    public func refresh() {
        guard banner.isShowing else { return }
        current = labels()
        banner.show(current)
    }

    private func show() {
        current = labels()
        banner.show(current)
        readings = 0
        tracking?.invalidate()
        let timer = Timer(timeInterval: Self.trackingInterval, repeats: true) { [weak self] _ in self?.track() }
        RunLoop.main.add(timer, forMode: .common)
        tracking = timer
        track()
    }

    private func track() {
        // Also the safety net for a missed "closed" signal: the labels must not stay on screen.
        guard let bars = watcher.desktopBars else { return hide() }
        guard labelsDesktops else { return }
        readings += 1
        if readings % Self.readingsPerNameRefresh == 0 { current = labels() }
        barLabels.show(bars.flatMap { bar -> [DesktopBarLabels.Label] in
            guard let display = current.first(where: { abs($0.displayBounds.minX - bar.displayFrame.minX) < 2 && abs($0.displayBounds.minY - bar.displayFrame.minY) < 2 }) else { return [] }
            return DesktopBarLabels.labels(for: bar, names: display.desktopNames, textWidth: DesktopBarLabels.measuredWidth)
        })
    }

    private func hide() {
        tracking?.invalidate()
        tracking = nil
        banner.hide()
        barLabels.hide()
    }
}
