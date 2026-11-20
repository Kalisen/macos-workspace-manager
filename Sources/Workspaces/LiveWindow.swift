public struct WindowFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A window as it exists right now on screen or on a hidden Space.
public struct LiveWindow: Equatable, Sendable {
    /// Window server ID. Stable until the window closes; reset by an app restart or reboot.
    public let windowID: Int
    public let pid: Int32
    public let bundleID: String
    public let appName: String
    /// Empty when the Screen Recording permission is missing.
    public let title: String
    public let spaceID: Int
    public let frame: WindowFrame

    public init(windowID: Int, pid: Int32, bundleID: String, appName: String, title: String, spaceID: Int, frame: WindowFrame) {
        self.windowID = windowID
        self.pid = pid
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.spaceID = spaceID
        self.frame = frame
    }
}
