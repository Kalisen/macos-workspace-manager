import AppKit

/// The workspace names to show on one display.
public struct WorkspaceLabel: Equatable {
    /// Name of the workspace currently showing, drawn large at the centre of the display. Empty draws nothing.
    public let text: String
    /// Display bounds in global top-left coordinates.
    public let displayBounds: CGRect
    /// One entry per desktop of the display, in Mission Control order. nil leaves the desktop unlabelled,
    /// which suits desktops without a custom name: Mission Control already writes "Desktop N" for them.
    public let desktopNames: [String?]

    public init(text: String, displayBounds: CGRect, desktopNames: [String?] = []) {
        self.text = text
        self.displayBounds = displayBounds
        self.desktopNames = desktopNames
    }
}

/// The current workspace name, large, at the centre of each display.
final class WorkspaceBanner {
    static let fontSize: CGFloat = 72
    private static let padding = CGSize(width: 48, height: 20)
    private static let maximumWidth = 0.8

    private(set) var windows: [LabelWindow] = []

    var isShowing: Bool { !windows.isEmpty }
    var windowNumbers: [Int] { windows.map(\.windowNumber) }

    func show(_ labels: [WorkspaceLabel]) {
        hide()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let font = NSFont.systemFont(ofSize: Self.fontSize, weight: .bold)
        windows = labels.filter { !$0.text.isEmpty }.map { label in
            let textSize = (label.text as NSString).size(withAttributes: [.font: font])
            let window = LabelWindow()
            window.show(label.text, font: font, frame: Self.frame(textSize: textSize, displayBounds: label.displayBounds, primaryHeight: primaryHeight), backgroundAlpha: 0.65)
            return window
        }
    }

    func hide() {
        windows.forEach { $0.close() }
        windows = []
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
