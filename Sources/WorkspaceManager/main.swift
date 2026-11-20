import AppKit
import MacDesktop

if CommandLine.arguments.contains("--status") {
    // Diagnostic snapshot of what the app sees; changes nothing.
    do {
        let layout = try SpaceReader.layout()
        let windows = WindowReader.windows(in: layout)
        let state = try StateStore.load()
        let focused = WindowReader.focusedWindowID()
        print("accessibility=\(AXIsProcessTrusted()) screenRecording=\(WindowReader.canReadTitles)")
        print("activeDisplay=\(SpaceReader.activeDisplayID(in: layout) ?? "none") focusedWindow=\(focused.map(String.init) ?? "none") tracked=\(windows.contains { $0.windowID == focused })")
        for display in layout.displays {
            print("display \(display.id)")
            for desktop in display.desktops where !desktop.isFullscreen {
                let mark = desktop.spaceID == display.currentSpaceID ? "*" : " "
                let count = windows.filter { $0.spaceID == desktop.spaceID }.count
                print("  \(mark) \(layout.ordinal(of: desktop.key) ?? 0). \(state.names.name(of: desktop.key, in: layout)) — \(count) windows")
            }
        }
        for item in state.book.displaced(windows, layout: layout) {
            print("displaced: \(item.window.appName) \"\(item.window.title)\" → \(state.names.name(of: item.home, in: layout))")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("status failed: \(error)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
app.run()
