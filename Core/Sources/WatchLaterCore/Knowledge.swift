import Foundation

// The three knowledge views over the same list: Find (search everything and
// say WHERE it matched), the Library (what he has been through, by when), and
// Topics (his tags, each one a subject that collects things).

// MARK: - Find

public struct Hit: Identifiable, Equatable {
    /// Where the words were found — decides the line under the title.
    public enum Place: Equatable {
        case title, channel, tag(String), note, body, blurb
        case mark(seconds: Int?)
        /// Found in what was said in the video, at that second.
        case said(seconds: Int)
    }
    public var id: String { item.id + "|" + snippet }
    public let item: Video
    public let place: Place
    /// A short stretch of the matching text with the match inside it.
    public let snippet: String
    /// The matched words as they appear in the snippet (for highlighting).
    public let match: String
    /// How many MORE times the words are said in the video, beyond this one.
    public var alsoSaid: Int = 0
}

/// Narrowing a search: what kind of thing, where it is, whether he wrote about it.
public struct FindFilter: Equatable {
    public enum Where: String, CaseIterable, Identifiable {
        case everywhere, waiting, library
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .everywhere: return "Everywhere"
            case .waiting:    return "Waiting"
            case .library:    return "Library"
            }
        }
    }
    public var kind: ItemKind?
    public var place: Where = .everywhere
    public var withNotes = false
    public init() {}

    public func admits(_ v: Video) -> Bool {
        if let k = kind, v.kind != k { return false }
        switch place {
        case .everywhere: break
        case .waiting: if !v.isOpen { return false }
        case .library: if v.watchedAt == nil { return false }
        }
        if withNotes && !v.hasNotes { return false }
        return true
    }
}

public enum Finder {

    /// Every item that mentions the words, once, at its best place: its title
    /// first, then his own marks and notes, then tags, channel and summary.
    /// Waiting things come before Library things; within each, newest first.
    public static func search(_ library: Library, _ query: String,
                              transcripts: [String: Transcript] = [:],
                              filter: FindFilter = FindFilter()) -> [Hit] {
        let needle = Shelf.fold(query)
        guard needle.count >= 2 else { return [] }
        var hits: [Hit] = []
        for v in library.live where filter.admits(v) {
            if let h = bestHit(in: v, needle: needle) { hits.append(h) }
            else if let id = v.videoId, let t = transcripts[id], let h = saidHit(in: v, t, needle: needle) { hits.append(h) }
        }
        return hits.sorted { a, b in
            if a.item.isOpen != b.item.isOpen { return a.item.isOpen }
            let da = a.item.watchedAt ?? a.item.savedAt, db = b.item.watchedAt ?? b.item.savedAt
            return da > db
        }
    }

    /// The first moment the words are said, and how many more times.
    static func saidHit(in v: Video, _ t: Transcript, needle: String) -> Hit? {
        var first: (Transcript.Line, Int)? = nil
        var count = 0
        for (i, line) in t.lines.enumerated() where Shelf.fold(line.s).contains(needle) {
            count += 1
            if first == nil { first = (line, i) }
        }
        guard let (line, i) = first else { return nil }
        // A line is a few seconds of speech — take its neighbours for context.
        let context = t.lines[max(0, i - 1)...min(t.lines.count - 1, i + 1)].map(\.s).joined(separator: " ")
        // Little before the words, so a two-line row still shows them.
        guard let s = snippet(context, needle, radius: 20) else { return nil }
        var h = Hit(item: v, place: .said(seconds: line.seconds), snippet: s.text, match: s.match)
        h.alsoSaid = count - 1
        return h
    }

    static func bestHit(in v: Video, needle: String) -> Hit? {
        if let s = snippet(v.title, needle) { return Hit(item: v, place: .title, snippet: s.text, match: s.match) }
        for m in v.sortedMarks {
            if let s = snippet(m.text, needle) {
                return Hit(item: v, place: .mark(seconds: m.seconds), snippet: s.text, match: s.match)
            }
        }
        if let s = snippet(v.note, needle) { return Hit(item: v, place: .note, snippet: s.text, match: s.match) }
        if let s = snippet(v.body, needle) { return Hit(item: v, place: .body, snippet: s.text, match: s.match) }
        for t in v.tags {
            if let s = snippet(t, needle) { return Hit(item: v, place: .tag(t), snippet: s.text, match: s.match) }
        }
        if let s = snippet(v.channel, needle) { return Hit(item: v, place: .channel, snippet: s.text, match: s.match) }
        if let s = snippet(v.blurb, needle) { return Hit(item: v, place: .blurb, snippet: s.text, match: s.match) }
        return nil
    }

    /// Up to `radius` characters either side of the first match, trimmed at
    /// word edges, with … where text was cut. Accent-blind: "somn" finds "sömn",
    /// and the snippet keeps his own spelling.
    public static func snippet(_ text: String, _ needle: String, radius: Int = 40) -> (text: String, match: String)? {
        guard !text.isEmpty else { return nil }
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        guard let r = flat.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) else { return nil }
        let match = String(flat[r])
        var start = flat.index(r.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex) ?? flat.startIndex
        var end = flat.index(r.upperBound, offsetBy: radius, limitedBy: flat.endIndex) ?? flat.endIndex
        // Do not cut a word in half.
        if start != flat.startIndex, let sp = flat[start..<r.lowerBound].firstIndex(of: " ") { start = flat.index(after: sp) }
        if end != flat.endIndex, let sp = flat[r.upperBound..<end].lastIndex(of: " ") { end = sp }
        var out = String(flat[start..<end]).trimmingCharacters(in: .whitespaces)
        if start != flat.startIndex { out = "…" + out }
        if end != flat.endIndex { out += "…" }
        return (out, match)
    }
}

// MARK: - Library

public enum LibraryShelf {
    public enum Filter: String, CaseIterable, Identifiable {
        case all, withNotes
        public var id: String { rawValue }
        public var title: String { self == .all ? "All" : "With notes" }
    }

    public struct Group: Identifiable, Equatable {
        public var id: String { title }
        public let title: String
        public let items: [Video]
    }

    /// Everything watched or read, newest first, in the three stretches of
    /// time a memory works in: this week, this month, earlier.
    public static func groups(_ library: Library, filter: Filter = .all, kind: ItemKind? = nil,
                              now: Date = Date()) -> [Group] {
        var done = library.live.filter { $0.watchedAt != nil }
        if filter == .withNotes { done = done.filter(\.hasNotes) }
        if let kind { done = done.filter { $0.kind == kind } }
        done.sort { ($0.watchedAt ?? .distantPast) > ($1.watchedAt ?? .distantPast) }
        let week = now.addingTimeInterval(-7 * 86_400), month = now.addingTimeInterval(-30 * 86_400)
        let buckets: [(String, (Date) -> Bool)] = [
            ("This week", { $0 >= week }),
            ("This month", { $0 < week && $0 >= month }),
            ("Earlier", { $0 < month }),
        ]
        return buckets.compactMap { title, test in
            let items = done.filter { test($0.watchedAt ?? .distantPast) }
            return items.isEmpty ? nil : Group(title: title, items: items)
        }
    }

    public static func markCount(_ library: Library) -> Int {
        library.live.filter { $0.watchedAt != nil }.reduce(0) { $0 + $1.marks.count }
    }
}

// MARK: - Topics

public struct Topic: Identifiable, Equatable {
    public var id: String { name.lowercased() }
    /// His spelling, as first written.
    public let name: String
    /// Waiting first, then the Library; newest first within each.
    public let items: [Video]
    public var waiting: Int { items.filter(\.isOpen).count }
    public var done: Int { items.count - waiting }
    public var marks: Int { items.reduce(0) { $0 + $1.marks.count } }

    /// "4 videos · 1 article · 3 marks"
    public var summary: String {
        var parts: [String] = []
        for k in ItemKind.allCases {
            let n = items.filter { $0.kind == k }.count
            guard n > 0 else { continue }
            let word: String
            switch k {
            case .video:   word = n == 1 ? "video" : "videos"
            case .article: word = n == 1 ? "article" : "articles"
            case .podcast: word = n == 1 ? "podcast" : "podcasts"
            case .page:    word = n == 1 ? "page" : "pages"
            }
            parts.append("\(n) \(word)")
        }
        if marks > 0 { parts.append("\(marks) mark\(marks == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

public enum Topics {
    /// One topic per tag, spelled as he first wrote it, biggest first.
    public static func all(_ library: Library) -> [Topic] {
        var spelling: [String: String] = [:]
        var members: [String: [Video]] = [:]
        for v in library.live {
            for t in v.tags {
                let key = t.lowercased()
                spelling[key] = spelling[key] ?? t
                members[key, default: []].append(v)
            }
        }
        return members.map { key, items in
            Topic(name: spelling[key]!, items: items.sorted { a, b in
                if a.isOpen != b.isOpen { return a.isOpen }
                return (a.watchedAt ?? a.savedAt) > (b.watchedAt ?? b.savedAt)
            })
        }
        .sorted { $0.items.count != $1.items.count ? $0.items.count > $1.items.count
                                                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
