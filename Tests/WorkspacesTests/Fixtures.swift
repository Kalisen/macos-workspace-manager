import Foundation
@testable import Workspaces

/// Display A: desktops one, two, a fullscreen Space, three. Display B: desktop seven.
let twoDisplays = DesktopLayout(displays: [
    Display(id: "A", desktops: [
        Desktop(spaceID: 1, key: "one"), Desktop(spaceID: 2, key: "two"),
        Desktop(spaceID: 9, key: "full", isFullscreen: true), Desktop(spaceID: 3, key: "three"),
    ], currentSpaceID: 1),
    Display(id: "B", desktops: [Desktop(spaceID: 7, key: "seven")], currentSpaceID: 7),
])

let someTime = Date(timeIntervalSince1970: 1_000_000)
let frameA = WindowFrame(x: 0, y: 0, width: 800, height: 600)
let frameB = WindowFrame(x: 50, y: 60, width: 400, height: 300)

func window(_ id: Int, space: Int, title: String = "notes", pid: Int32 = 10, bundle: String = "app.term", frame: WindowFrame = frameA) -> LiveWindow {
    LiveWindow(windowID: id, pid: pid, bundleID: bundle, appName: "Term", title: title, spaceID: space, frame: frame)
}

extension PlacementBook {
    /// Observes on the two-display layout.
    mutating func see(_ windows: [LiveWindow], session: String = "boot1", trusted: Bool = true, at date: Date = someTime) {
        observe(windows, layout: twoDisplays, session: session, trusted: trusted, now: date)
    }

    func homes(of windows: [LiveWindow]) -> [WorkspaceKey?] {
        windows.map { home(ofWindow: $0.windowID) }
    }
}
