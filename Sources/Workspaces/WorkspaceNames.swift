/// User-given names of workspaces. Unnamed workspaces fall back to "Desktop N".
public struct WorkspaceNames: Codable, Equatable, Sendable {
    private var custom: [WorkspaceKey: String]

    public init(custom: [WorkspaceKey: String] = [:]) {
        self.custom = custom
    }

    public func name(of key: WorkspaceKey, in layout: DesktopLayout) -> String {
        if let name = custom[key] { return name }
        if let ordinal = layout.ordinal(of: key) { return "Desktop \(ordinal)" }
        return "Missing desktop"
    }

    /// nil for a workspace the user has not named.
    public func customName(of key: WorkspaceKey) -> String? {
        custom[key]
    }

    /// An empty name removes the custom name.
    public mutating func rename(_ key: WorkspaceKey, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        custom[key] = trimmed.isEmpty ? nil : trimmed
    }

    public init(from decoder: Decoder) throws {
        custom = try decoder.singleValueContainer().decode([WorkspaceKey: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(custom)
    }
}
