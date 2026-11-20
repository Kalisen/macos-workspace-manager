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
        // Optional feature, isolated: workspace name shown over Mission Control. Depends on nothing else.
        .target(name: "MissionControlBanner"),
        .executableTarget(name: "WorkspaceManager", dependencies: ["Workspaces", "MacDesktop", "MissionControlBanner"]),
        .testTarget(name: "WorkspacesTests", dependencies: ["Workspaces"]),
        .testTarget(name: "MacDesktopTests", dependencies: ["MacDesktop"]),
        .testTarget(name: "MissionControlBannerTests", dependencies: ["MissionControlBanner"]),
        .testTarget(name: "WorkspaceManagerTests", dependencies: ["WorkspaceManager"]),
    ]
)
