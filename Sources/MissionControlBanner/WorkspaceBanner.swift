import AppKit

/// The workspace names to show on one display.
public struct WorkspaceLabel: Equatable {
    /// One desktop of the Mission Control bar.
    public struct Desktop: Equatable {
        /// Identifies the desktop in rename requests. nil for a Space that cannot be named (fullscreen).
        public let id: String?
        /// nil leaves the desktop unlabelled, which suits desktops without a custom name:
        /// Mission Control already writes "Desktop N" for them.
        public let name: String?

        public init(id: String?, name: String?) {
            self.id = id
            self.name = name
        }
    }

    /// Name of the workspace currently showing, drawn large at the centre of the display. Empty draws nothing.
    public let text: String
    /// Identifies the workspace currently showing in rename requests.
    public let currentID: String?
    /// Display bounds in global top-left coordinates.
    public let displayBounds: CGRect
    /// The desktops of the display, in Mission Control order.
    public let desktops: [Desktop]

    public init(text: String, currentID: String? = nil, displayBounds: CGRect, desktops: [Desktop] = []) {
        self.text = text
        self.currentID = currentID
        self.displayBounds = displayBounds
        self.desktops = desktops
    }
}

/// The current workspace name, large, at the centre of each display.
final class WorkspaceBanner {
    static let fontSize: CGFloat = 72
    private static let padding = CGSize(width: 48, height: 20)
    private static let maximumWidth = 0.8

    private(set) var windows: [LabelWindow] = []
    /// The labels the windows were made from, in the same order.
    private(set) var drawn: [WorkspaceLabel] = []

    var isShowing: Bool { !windows.isEmpty }
    var windowNumbers: [Int] { windows.map(\.windowNumber) }

    func show(_ labels: [WorkspaceLabel]) {
        hide()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let font = NSFont.systemFont(ofSize: Self.fontSize, weight: .bold)
        drawn = labels.filter { !$0.text.isEmpty }
        windows = drawn.map { label in
            let textSize = (label.text as NSString).size(withAttributes: [.font: font])
            let window = LabelWindow()
            window.show(label.text, font: font, frame: Self.frame(textSize: textSize, displayBounds: label.displayBounds, primaryHeight: primaryHeight), backgroundAlpha: 0.65)
            return window
        }
    }

    func hide() {
        windows.forEach { $0.close() }
        windows = []
        drawn = []
    }

    /// Index, among the labels last shown, of the large name under a point in AppKit coordinates.
    func index(at point: NSPoint) -> Int? {
        windows.firstIndex { $0.frame.contains(point) }
    }

    /// Label frame in AppKit coordinates (origin at the bottom-left of the primary display):
    /// centred on its display, never wider than the display allows.
    static func frame(textSize: CGSize, displayBounds: CGRect, primaryHeight: CGFloat) -> NSRect {
        let width = min(textSize.width + padding.width, displayBounds.width * maximumWidth)
        let height = textSize.height + padding.height
        let displayBottom = primaryHeight - displayBounds.maxY
        return NSRect(x: displayBounds.midX - width / 2, y: displayBottom + (displayBounds.height - height) / 2, width: width, height: height)
    }
}
