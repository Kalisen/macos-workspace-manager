// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkspaceManager",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure domain: workspaces, window placements, matching. No system calls.
        .target(name: "Workspaces"),
        // macOS adapter: Spaces reading, window reading, window moving.
        .target(name: "MacDesktop", dependencies: ["Workspaces"]),
        .executableTarget(name: "WorkspaceManager", dependencies: ["Workspaces", "MacDesktop"]),
        .testTarget(name: "WorkspacesTests", dependencies: ["Workspaces"]),
        .testTarget(name: "MacDesktopTests", dependencies: ["MacDesktop"]),
    ]
)
