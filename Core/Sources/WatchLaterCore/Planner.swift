import Foundation

/// "I have 45 minutes, make something of it." An exact 0/1 knapsack over whole
/// minutes, not a filter: the answer fills the time as closely as it can.
public enum Planner {

    public static let budgets = [30, 45, 60, 90, 120]

    /// Whole minutes a video costs — never zero, so a two-second clip is still
    /// something.
    public static func minutes(_ v: Video) -> Int? {
        guard let s = v.seconds else { return nil }
        return max(1, Int((Double(s) / 60).rounded()))
    }

    /// The candidates are shuffled before each run, so "Try another" gives a
    /// genuinely different evening rather than the same one reordered — the
    /// table keeps the first of several equally good answers. Ties lean towards
    /// clearing something pinned or stale, which is why the score is minutes
    /// with a little bonus, not plain minutes.
    public static func plan(minutes budget: Int, from pool: [Video], now: Date = Date(),
                            shuffle: Bool = true) -> [Video] {
        var items = pool.filter { !$0.countsAsShort && minutes($0) != nil && minutes($0)! <= budget }
        if shuffle { items.shuffle() }
        guard !items.isEmpty, budget > 0 else { return [] }
        let cost = items.map { minutes($0)! }
        let worth = items.enumerated().map { i, v in
            cost[i] * 10 + (v.isPinned || v.isStale(now: now) ? 3 : 0)
        }
        // best[i][w]: best worth using the first i items within w minutes
        var best = Array(repeating: Array(repeating: 0, count: budget + 1), count: items.count + 1)
        for i in 1...items.count {
            for w in 0...budget {
                best[i][w] = best[i - 1][w]
                if cost[i - 1] <= w {
                    let with = best[i - 1][w - cost[i - 1]] + worth[i - 1]
                    if with > best[i][w] { best[i][w] = with }
                }
            }
        }
        var picked: [Video] = []
        var w = budget
        for i in stride(from: items.count, to: 0, by: -1) where best[i][w] != best[i - 1][w] {
            picked.append(items[i - 1])
            w -= cost[i - 1]
        }
        // Longest first reads like a programme.
        return picked.sorted { ($0.seconds ?? 0) > ($1.seconds ?? 0) }
    }
}

/// A set of videos as one message: numbered titles with lengths, and one link
/// that plays them in order. Nothing is sent by the app — it goes to the
/// clipboard and he chooses where.
public enum Together {
    public static func link(for videos: [Video]) -> String? {
        let ids = videos.compactMap(\.videoId)
        return ids.isEmpty ? nil : YouTube.playlistLink(for: ids)
    }

    public static func message(for videos: [Video], heading: String = "Shall we watch these?") -> String {
        var lines = [heading, ""]
        for (i, v) in videos.enumerated() {
            let badge = Clock.badge(v.seconds).map { " (\($0))" } ?? ""
            lines.append("\(i + 1). \(v.title)\(badge)")
        }
        if let l = link(for: videos) { lines += ["", l] }
        return lines.joined(separator: "\n")
    }
}
