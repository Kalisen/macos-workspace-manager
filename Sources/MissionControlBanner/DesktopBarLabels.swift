import AppKit

/// Workspace names drawn over the desktops of the Mission Control bar.
final class DesktopBarLabels {
    struct Label: Equatable {
        let text: String
        /// Global top-left coordinates.
        let frame: CGRect
        let fontSize: CGFloat
    }

    /// Slightly smaller than the Dock's own text: a custom name is usually longer than "Desktop N"
    /// and has to fit the room the Dock left for it.
    private static let nameFontSize: CGFloat = 12
    private static let previewFontSize: CGFloat = 20
    private static let namePadding: CGFloat = 10
    private static let nameMargin: CGFloat = 2
    private static let previewPadding: CGFloat = 16
    private static let previewMargin: CGFloat = 6

    private var windows: [LabelWindow] = []
    private var shown: [Label] = []

    var windowNumbers: [Int] { windows.map(\.windowNumber) }

    /// Redraws only when something moved or changed; called many times a second while Mission Control is open.
    func show(_ labels: [Label]) {
        guard labels != shown else { return }
        shown = labels
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        while windows.count < labels.count { windows.append(LabelWindow()) }
        while windows.count > labels.count { windows.removeLast().close() }
        for (window, label) in zip(windows, labels) {
            let frame = NSRect(x: label.frame.minX, y: primaryHeight - label.frame.maxY, width: label.frame.width, height: label.frame.height)
            window.show(label.text, font: .systemFont(ofSize: label.fontSize, weight: .semibold), frame: frame, backgroundAlpha: 0.85)
        }
    }

    func hide() {
        show([])
    }

    /// Labels for the named desktops of one display.
    /// - A collapsed bar shows names only: the label replaces the "Desktop N" text.
    /// - An expanded bar shows previews: the label sits in the middle of the preview.
    /// A bar whose desktops do not match the names one-to-one is left unlabelled rather than mislabelled.
    static func labels(for bar: DesktopBar, names: [String?], textWidth: (String, CGFloat) -> CGFloat) -> [Label] {
        guard bar.desktops.count == names.count else { return [] }
        return names.enumerated().compactMap { index, name in
            guard let name, let slot = bar.slot(index) else { return nil }
            switch slot {
            case .name(let rect):
                let width = min(textWidth(name, nameFontSize) + namePadding, bar.spacing(around: index) - nameMargin)
                return Label(text: name, frame: CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height), fontSize: nameFontSize)
            case .preview(let rect):
                let width = min(textWidth(name, previewFontSize) + previewPadding, rect.width - previewMargin * 2)
                let height = previewFontSize + 12
                return Label(text: name, frame: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height), fontSize: previewFontSize)
            }
        }
    }

    static func measuredWidth(_ text: String, _ fontSize: CGFloat) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)]).width)
    }
}
