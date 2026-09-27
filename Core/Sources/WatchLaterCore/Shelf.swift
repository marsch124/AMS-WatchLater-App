import Foundation

/// Sort by time available, not by date. He never asks "what did I save on
/// Tuesday"; he asks "I have twenty minutes".
public enum Bucket: String, CaseIterable, Identifiable {
    case five, twenty, hour, everything

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .five:       return "5 min"
        case .twenty:     return "20 min"
        case .hour:       return "An hour"
        case .everything: return "Everything"
        }
    }

    public var maxSeconds: Int? {
        switch self {
        case .five:       return 5 * 60
        case .twenty:     return 20 * 60
        case .hour:       return 60 * 60
        case .everything: return nil
        }
    }

    /// Shorts are out of the timed slots — an eleven-second clip is not "five
    /// minutes" — but counted under Everything.
    public func fits(_ v: Video) -> Bool {
        guard let max = maxSeconds else { return true }
        guard let s = v.seconds, !v.countsAsShort else { return false }
        return s <= max
    }
}

public enum Sort: String, CaseIterable, Identifiable {
    case newest, shortest, longest
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .newest:   return "Newest"
        case .shortest: return "Shortest"
        case .longest:  return "Longest"
        }
    }
}

/// What is on screen: one place decides, so the pills, the total and the
/// evening planner can never disagree about which videos are meant.
public struct Shelf: Equatable {
    public var bucket: Bucket = .everything
    public var showWatched = false
    public var shortsOnly = false
    public var togetherOnly = false
    public var channel: String?
    public var tag: String?
    public var search = ""
    public var sort: Sort = .newest
    /// Only videos, only articles … nil = everything.
    public var kind: ItemKind?

    public init() {}

    public func apply(to library: Library, now: Date = Date()) -> [Video] {
        var rows = library.live.filter { showWatched ? $0.watchedAt != nil : $0.isOpen }
        if shortsOnly {
            rows = rows.filter { $0.countsAsShort }
        } else if !showWatched {
            rows = rows.filter { bucket.fits($0) }
        }
        if togetherOnly { rows = rows.filter { $0.isTogether } }
        if let k = kind { rows = rows.filter { $0.kind == k } }
        if let c = channel { rows = rows.filter { $0.channel == c } }
        if let t = tag { rows = rows.filter { $0.tags.contains { $0.caseInsensitiveCompare(t) == .orderedSame } } }
        let needle = Shelf.fold(search)
        if !needle.isEmpty {
            rows = rows.filter {
                Shelf.fold($0.title).contains(needle) || Shelf.fold($0.channel).contains(needle)
                    || Shelf.fold($0.note).contains(needle) || Shelf.fold($0.body).contains(needle)
                    || Shelf.fold($0.blurb).contains(needle)
                    || $0.tags.contains { Shelf.fold($0).contains(needle) }
                    || $0.marks.contains { Shelf.fold($0.text).contains(needle) }
            }
        }
        return rows.sorted { a, b in
            // Pinned first (newest pin on top), then the ones asking for a
            // decision, then the chosen order.
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.isPinned, let x = a.pinnedAt, let y = b.pinnedAt, x != y { return x > y }
            let sa = a.isStale(now: now), sb = b.isStale(now: now)
            if sa != sb { return sa }
            switch sort {
            case .newest:   return a.savedAt > b.savedAt
            case .shortest: return (a.seconds ?? .max) < (b.seconds ?? .max)
            case .longest:  return (a.seconds ?? -1) > (b.seconds ?? -1)
            }
        }
    }

    /// Accent-blind and case-blind, so *hjarnans* finds *hjärnans*.
    public static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// How many open videos fit each slot — the little number on each pill.
    public static func counts(_ library: Library) -> [Bucket: Int] {
        var out: [Bucket: Int] = [:]
        let open = library.open
        for b in Bucket.allCases { out[b] = open.filter { b.fits($0) }.count }
        return out
    }

    /// Which kinds are on the open list, and how many of each — the kind pills
    /// only appear once there is more than one kind to choose between.
    public static func kinds(_ library: Library, done showDone: Bool = false) -> [(kind: ItemKind, count: Int)] {
        let rows = showDone ? library.live.filter { $0.watchedAt != nil } : library.open
        return ItemKind.allCases.compactMap { k in
            let n = rows.filter { $0.kind == k }.count
            return n > 0 ? (k, n) : nil
        }
    }

    public static func shortsCount(_ library: Library) -> Int {
        library.open.filter { $0.countsAsShort }.count
    }

    public static func togetherCount(_ library: Library) -> Int {
        library.open.filter { $0.isTogether }.count
    }

    public static func channels(_ library: Library) -> [String] {
        Array(Set(library.open.map(\.channel).filter { !$0.isEmpty })).sorted()
    }

    public static func tags(_ library: Library) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for v in library.open {
            for t in v.tags {
                counts[t.lowercased(), default: 0] += 1
                spelling[t.lowercased()] = spelling[t.lowercased()] ?? t
            }
        }
        return counts.keys.sorted().map { (spelling[$0]!, counts[$0]!) }
    }
}

// MARK: - Words for time

public enum Clock {
    /// 15:32, or 1:02:03.
    public static func badge(_ seconds: Int?) -> String? {
        guard let s = seconds else { return nil }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// "2 h 23 min", "48 min", "under a minute". A trailing "+" when something
    /// counted has no length yet.
    public static func total(_ videos: [Video]) -> String {
        let known = videos.compactMap(\.seconds)
        let sum = known.reduce(0, +)
        var s: String
        let h = sum / 3600, m = (sum % 3600 + 59) / 60
        if h > 0 { s = m > 0 && m < 60 ? "\(h) h \(m) min" : "\(h) h" }
        else if m > 0 { s = "\(m) min" }
        else { s = sum > 0 ? "under a minute" : "0 min" }
        if known.count < videos.count { s += "+" }
        return s
    }

    /// "Saved today", "Saved 3 days ago", "Saved last month"; or, for a video
    /// he opened and has not answered about, "Started yesterday".
    public static func age(of v: Video, now: Date = Date()) -> String {
        if v.awaitsAnswer, let started = v.startedAt {
            return "Started " + relative(started, now: now)
        }
        return "Saved " + relative(v.savedAt, now: now)
    }

    public static func relative(_ date: Date, now: Date = Date()) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        switch days {
        case ..<1:  return "today"
        case 1:     return "yesterday"
        case 2..<7: return "\(days) days ago"
        case 7..<14: return "last week"
        case 14..<30: return "\(days / 7) weeks ago"
        case 30..<60: return "last month"
        case 60..<365: return "\(days / 30) months ago"
        default: return "over a year ago"
        }
    }
}
