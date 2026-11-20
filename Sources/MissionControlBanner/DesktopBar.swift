import ApplicationServices

/// The strip of desktops at the top of a display in Mission Control, as the Dock describes it.
/// Frames are in global top-left coordinates.
struct DesktopBar: Equatable {
    let displayFrame: CGRect
    let frame: CGRect
    /// One per desktop, in order: the name when the bar is collapsed, the preview when it is expanded.
    let desktops: [CGRect]

    /// Where a desktop is drawn, and in which form.
    enum Slot: Equatable {
        /// Collapsed bar: only the desktop name is shown.
        case name(CGRect)
        /// Expanded bar: a preview of the desktop is shown.
        case preview(CGRect)
    }

    /// Height of a desktop name in a collapsed bar; previews are taller.
    private static let nameHeight: CGFloat = 30

    /// nil when the reported frame cannot be placed inside the bar, so that no label is drawn in a wrong spot.
    func slot(_ index: Int) -> Slot? {
        guard desktops.indices.contains(index) else { return nil }
        var rect = desktops[index]
        // While collapsed, the Dock reports the names one bar-height above where it draws them.
        if rect.maxY <= frame.minY { rect = rect.offsetBy(dx: 0, dy: frame.height) }
        guard frame.insetBy(dx: 0, dy: -1).contains(rect) else { return nil }
        return rect.height <= Self.nameHeight ? .name(rect) : .preview(rect)
    }

    /// Index of the desktop drawn under a point, in global top-left coordinates.
    func desktopIndex(at point: CGPoint) -> Int? {
        desktops.indices.first { index in
            switch slot(index) {
            case .name(let rect): rect.insetBy(dx: -Self.nameHitMargin, dy: -Self.nameHitMargin).contains(point)
            case .preview(let rect): rect.contains(point)
            case nil: false
            }
        }
    }

    /// A desktop name is a small target; a click just beside it still counts.
    private static let nameHitMargin: CGFloat = 6

    /// Room available to a label centred on a desktop, bounded by its neighbours.
    func spacing(around index: Int) -> CGFloat {
        let centres = desktops.map(\.midX)
        let gaps = [index - 1, index + 1].filter(centres.indices.contains).map { abs(centres[$0] - centres[index]) }
        return gaps.min() ?? frame.width
    }
}

/// Reads the desktop bars from the Dock's accessibility tree. The identifiers are undocumented:
/// when they change, no bar is found and no desktop label is drawn.
enum DesktopBarReader {
    private static let missionControl = "mc", display = "mc.display", bar = "mc.spaces", list = "mc.spaces.list"

    /// nil when Mission Control is not showing.
    static func bars(in dock: AXUIElement) -> [DesktopBar]? {
        guard let root = children(of: dock).first(where: { identifier(of: $0) == missionControl }) else { return nil }
        return children(of: root).filter { identifier(of: $0) == display }.compactMap { displayElement in
            guard let displayFrame = frame(of: displayElement),
                  let barElement = children(of: displayElement).first(where: { identifier(of: $0) == bar }),
                  let barFrame = frame(of: barElement),
                  let listElement = children(of: barElement).first(where: { identifier(of: $0) == list }) else { return nil }
            return DesktopBar(displayFrame: displayFrame, frame: barFrame, desktops: children(of: listElement).compactMap(frame))
        }
    }

    private static func value(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        value(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    }

    private static func identifier(of element: AXUIElement) -> String? {
        value(kAXIdentifierAttribute, of: element) as? String
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let value = value("AXFrame", of: element), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
    }
}
