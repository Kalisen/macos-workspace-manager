/// Re-identifies windows after an app restart or reboot, when window IDs have changed.
enum WindowMatching {
    static let minimumSimilarity = 0.5

    /// 0...1 word overlap between two titles.
    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let wordsA = words(a), wordsB = words(b)
        if wordsA.isEmpty || wordsB.isEmpty { return 0 }
        return Double(wordsA.intersection(wordsB).count) / Double(wordsA.union(wordsB).count)
    }

    private static func words(_ title: String) -> Set<String> {
        Set(title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    /// One-to-one pairing of windows with the placements of windows that no longer exist under their old ID.
    /// Among equally similar candidates, the placement whose home is where the window already sits wins.
    static func pair(
        windows: [LiveWindow],
        placements: [Placement],
        currentKey: (LiveWindow) -> WorkspaceKey?
    ) -> [(window: Int, placement: Int)] {
        var candidates: [(score: Double, window: Int, placement: Int)] = []
        for (w, window) in windows.enumerated() {
            for (p, placement) in placements.enumerated()
            where placement.bundleID == window.bundleID && placement.pid != window.pid {
                let score = similarity(window.title, placement.title)
                guard score >= minimumSimilarity else { continue }
                let atHome = currentKey(window) == placement.home
                candidates.append((score + (atHome ? 0.001 : 0), w, p))
            }
        }
        candidates.sort { $0.score > $1.score }
        var usedWindows = Set<Int>(), usedPlacements = Set<Int>()
        var pairs: [(window: Int, placement: Int)] = []
        for candidate in candidates
        where !usedWindows.contains(candidate.window) && !usedPlacements.contains(candidate.placement) {
            usedWindows.insert(candidate.window)
            usedPlacements.insert(candidate.placement)
            pairs.append((candidate.window, candidate.placement))
        }
        return pairs
    }
}
