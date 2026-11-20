import AppKit

/// A workspace name to show on one display.
public struct WorkspaceLabel: Equatable {
    public let text: String
    /// Display bounds in global top-left coordinates.
    public let displayBounds: CGRect

    public init(text: String, displayBounds: CGRect) {
        self.text = text
        self.displayBounds = displayBounds
    }
}

/// Large labels that stay in place above Mission Control.
final class WorkspaceBanner {
    static let fontSize: CGFloat = 72
    private static let padding = CGSize(width: 48, height: 20)
    /// Fraction of the display height between the bottom of the display and the label.
    private static let bottomMargin = 0.08
    private static let maximumWidth = 0.8

    private(set) var windows: [NSWindow] = []

    var isShowing: Bool { !windows.isEmpty }
    var windowNumbers: [Int] { windows.map(\.windowNumber) }

    func show(_ labels: [WorkspaceLabel]) {
        hide()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        windows = labels.map { label in
            let text = NSTextField(labelWithString: label.text)
            text.font = .systemFont(ofSize: Self.fontSize, weight: .bold)
            text.textColor = .white
            text.lineBreakMode = .byTruncatingTail
            text.alignment = .center
            let frame = Self.frame(textSize: text.fittingSize, displayBounds: label.displayBounds, primaryHeight: primaryHeight)

            let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            // Mission Control shrinks ordinary windows into thumbnails; stationary windows are left where they are.
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false

            let background = NSView(frame: NSRect(origin: .zero, size: frame.size))
            // The layer is assigned explicitly: one created on demand does not exist yet at this point.
            let pill = CALayer()
            pill.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
            pill.cornerRadius = frame.height / 4
            background.layer = pill
            background.wantsLayer = true
            text.frame = background.bounds.insetBy(dx: Self.padding.width / 2, dy: Self.padding.height / 2)
            background.addSubview(text)
            window.contentView = background
            window.orderFrontRegardless()
            return window
        }
    }

    func hide() {
        windows.forEach { $0.close() }
        windows = []
    }

    /// Label frame in AppKit coordinates (origin at the bottom-left of the primary display):
    /// centred horizontally, near the bottom of its display, never wider than the display allows.
    static func frame(textSize: CGSize, displayBounds: CGRect, primaryHeight: CGFloat) -> NSRect {
        let width = min(textSize.width + padding.width, displayBounds.width * maximumWidth)
        let height = textSize.height + padding.height
        let displayBottom = primaryHeight - displayBounds.maxY
        return NSRect(x: displayBounds.midX - width / 2, y: displayBottom + displayBounds.height * bottomMargin, width: width, height: height)
    }
}
