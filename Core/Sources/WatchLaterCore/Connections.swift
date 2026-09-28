import Foundation

/// Step 3 — connecting what he saved: links he made, the cards that link
/// back, and what might belong together.
public enum Connections {

    /// One card connected to another, and which way the link runs.
    public struct Link: Identifiable, Equatable {
        public enum Way: Equatable { case to, from, both }
        public let item: Video
        public let way: Way
        /// He made it with "Link to…" (so it can be removed there), rather
        /// than only by writing [[Title]] in a note.
        public let made: Bool
        public var id: String { item.id }
    }

    /// `[[Title]]` and `[[Title|shown words]]` in a note — Obsidian's own
    /// spelling, so the export in step 5 keeps them as links.
    public static func wikiTitles(in text: String) -> [String] {
        guard text.contains("[[") else { return [] }
        let re = try! NSRegularExpression(pattern: #"\[\[([^\[\]\|\n]+)(?:\|[^\[\]\n]*)?\]\]"#)
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
    }

    /// What a card points at: the links he made, then [[titles]] in its note
    /// and marks that name another card. Removed cards drop out.
    public static func outgoing(_ v: Video, in library: Library) -> [(item: Video, made: Bool)] {
        let live = library.live
        var byID: [String: Video] = [:]
        for x in live { byID[x.id] = x }
        var byTitle: [String: Video] = [:]
        for x in live where !x.title.isEmpty { byTitle[Shelf.fold(x.title)] = byTitle[Shelf.fold(x.title)] ?? x }
        var out: [(Video, Bool)] = []
        var seen: Set<String> = [v.id]
        for id in v.links {
            if let x = byID[id], seen.insert(x.id).inserted { out.append((x, true)) }
        }
        let written = ([v.body, v.note] + v.marks.map(\.text)).flatMap(wikiTitles)
        for t in written {
            if let x = byTitle[Shelf.fold(t)], seen.insert(x.id).inserted { out.append((x, false)) }
        }
        return out
    }

    /// Every card connected to this one, in either direction. A link both
    /// ways shows once.
    public static func all(_ v: Video, in library: Library) -> [Link] {
        var result: [Link] = []
        var index: [String: Int] = [:]
        for (x, made) in outgoing(v, in: library) {
            index[x.id] = result.count
            result.append(Link(item: x, way: .to, made: made))
        }
        for x in library.live where x.id != v.id {
            guard outgoing(x, in: library).contains(where: { $0.item.id == v.id }) else { continue }
            if let i = index[x.id] {
                result[i] = Link(item: x, way: .both, made: result[i].made)
            } else {
                result.append(Link(item: x, way: .from, made: false))
            }
        }
        return result
    }

    /// Short everyday words that say nothing about what a thing is about.
    static let quiet: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "what", "your", "you", "are", "how", "why",
        "minutes", "minute", "about", "into", "over", "more", "most", "part", "episode", "video",
        "och", "att", "det", "som", "för", "med", "den", "till", "har", "inte", "der", "die", "das", "und",
    ]

    static func words(_ v: Video) -> Set<String> {
        let text = [v.title, v.blurb].joined(separator: " ")
        let parts = Shelf.fold(text).components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(parts.filter { $0.count >= 4 && !quiet.contains($0) })
    }

    /// What might belong with this card, best first: shared tags count most,
    /// then the same channel or site, then the same words in title and
    /// summary. Cards already connected are left out — they are there already.
    public static func related(to v: Video, in library: Library, limit: Int = 3) -> [Video] {
        let connected = Set(all(v, in: library).map(\.item.id))
        let myTags = Set(v.tags.map { Shelf.fold($0) })
        let myWords = words(v)
        let myChannel = Shelf.fold(v.channel)
        let scored: [(Video, Int)] = library.live.compactMap { x in
            guard x.id != v.id, !connected.contains(x.id) else { return nil }
            var score = 3 * myTags.intersection(x.tags.map { Shelf.fold($0) }).count
            if !myChannel.isEmpty && Shelf.fold(x.channel) == myChannel { score += 2 }
            score += myWords.intersection(words(x)).count
            return score >= 2 ? (x, score) : nil
        }
        return scored.sorted { a, b in
            a.1 != b.1 ? a.1 > b.1 : a.0.savedAt > b.0.savedAt
        }.prefix(limit).map(\.0)
    }

    /// Topics that share cards with this one, most shared first.
    public static func relatedTopics(_ topic: Topic, in library: Library, limit: Int = 6) -> [(topic: Topic, shared: Int)] {
        let mine = Set(topic.items.map(\.id))
        return Topics.all(library).compactMap { t in
            guard t.id != topic.id else { return nil }
            let n = t.items.filter { mine.contains($0.id) }.count
            return n > 0 ? (t, n) : nil
        }
        .sorted { $0.shared != $1.shared ? $0.shared > $1.shared : $0.topic.items.count > $1.topic.items.count }
        .prefix(limit).map { $0 }
    }
}
