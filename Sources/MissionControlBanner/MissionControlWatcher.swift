import AppKit
import ApplicationServices

public enum MissionControlWatcherError: Error, CustomStringConvertible {
    case accessibilityDenied
    case dockNotRunning
    case observerRefused(Int32)

    public var description: String {
        switch self {
        case .accessibilityDenied: "Accessibility permission is missing"
        case .dockNotRunning: "the Dock is not running"
        case .observerRefused(let code): "the Dock refused the accessibility observer (code \(code))"
        }
    }
}

/// Tells when Mission Control opens and closes.
///
/// macOS has no public signal for this. Mission Control is drawn by the Dock, which posts undocumented
/// accessibility notifications; a macOS release can remove them, in which case nothing is reported.
public final class MissionControlWatcher {
    private static let opened = "AXExposeShowAllWindows"
    private static let closed = "AXExposeExit"
    /// Accessibility identifier of the group the Dock exposes while Mission Control is showing.
    private static let groupIdentifier = "mc"
    private static let dockBundleID = "com.apple.dock"

    public var onOpen: (() -> Void)?
    public var onClose: (() -> Void)?

    private var observer: AXObserver?
    private var dock: AXUIElement?
    private var relaunchToken: NSObjectProtocol?

    public init() {}

    deinit {
        detach()
        if let relaunchToken { NSWorkspace.shared.notificationCenter.removeObserver(relaunchToken) }
    }

    /// Call on the main thread; the callbacks are delivered there.
    public func start() throws {
        try attach()
        // The Dock restarts after a crash or `killall Dock`; the observer dies with the old process.
        relaunchToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == Self.dockBundleID else { return }
            self.detach()
            self.onClose?()
            do {
                try self.attach()
            } catch {
                self.onAttachFailure?(error)
            }
        }
    }

    /// Reports a failure to follow a relaunched Dock.
    public var onAttachFailure: ((Error) -> Void)?

    /// Whether Mission Control is showing right now, read from the Dock.
    public var isOpen: Bool {
        guard let dock else { return false }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dock, kAXChildrenAttribute as CFString, &children) == .success,
              let elements = children as? [AXUIElement] else { return false }
        return elements.contains { element in
            var identifier: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier) == .success
                && identifier as? String == Self.groupIdentifier
        }
    }

    private func attach() throws {
        guard AXIsProcessTrusted() else { throw MissionControlWatcherError.accessibilityDenied }
        guard let process = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID).first else {
            throw MissionControlWatcherError.dockNotRunning
        }
        var created: AXObserver?
        let status = AXObserverCreate(process.processIdentifier, { _, _, notification, context in
            guard let context else { return }
            let watcher = Unmanaged<MissionControlWatcher>.fromOpaque(context).takeUnretainedValue()
            if notification as String == MissionControlWatcher.opened { watcher.onOpen?() } else { watcher.onClose?() }
        }, &created)
        guard status == .success, let created else { throw MissionControlWatcherError.observerRefused(status.rawValue) }
        let element = AXUIElementCreateApplication(process.processIdentifier)
        for name in [Self.opened, Self.closed] {
            let added = AXObserverAddNotification(created, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            guard added == .success else { throw MissionControlWatcherError.observerRefused(added.rawValue) }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        dock = element
    }

    private func detach() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
        dock = nil
    }
}
