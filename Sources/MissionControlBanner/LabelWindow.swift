import AppKit

/// A click-through text label that Mission Control leaves in place.
final class LabelWindow: NSWindow {
    private let text = NSTextField(labelWithString: "")
    private let pill = CALayer()

    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        // Mission Control shrinks ordinary windows into thumbnails; stationary windows are left where they are.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        let background = NSView()
        // The layer is assigned explicitly: one created on demand does not exist yet at this point.
        background.layer = pill
        background.wantsLayer = true
        text.textColor = .white
        text.lineBreakMode = .byTruncatingTail
        text.alignment = .center
        background.addSubview(text)
        contentView = background
    }

    /// - Parameter frame: AppKit coordinates.
    func show(_ string: String, font: NSFont, frame: NSRect, backgroundAlpha: CGFloat) {
        text.stringValue = string
        text.font = font
        setFrame(frame, display: false)
        pill.backgroundColor = NSColor.black.withAlphaComponent(backgroundAlpha).cgColor
        pill.cornerRadius = min(frame.height / 4, 12)
        let height = min(text.fittingSize.height, frame.height)
        text.frame = NSRect(x: 4, y: (frame.height - height) / 2, width: max(frame.width - 8, 0), height: height)
        orderFrontRegardless()
    }

    var labelText: String { text.stringValue }
    var backgroundAlpha: CGFloat { pill.backgroundColor?.alpha ?? 0 }
}
