import Foundation

/// Step 5 — the knowledge base leaves the app: one Markdown note per card for
/// Obsidian (with [[links]] that resolve), a note per topic, an index; and a
/// spreadsheet of everything.
public enum ObsidianExport {
    public struct Note: Equatable {
        public let path: String      // inside the export folder, e.g. "Topics/Sleep.md"
        public let text: String
    }

    /// The folder it writes into, inside the vault he chooses.
    public static let folder = "WatchLater"

    /// A file name Obsidian and both file systems accept: no / \ : * ? " < > |
    /// # ^ [ ] and no leading dot; short enough; never empty.
    public static func fileName(_ title: String) -> String {
        let banned = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]\n\r\t")
        var s = title.components(separatedBy: banned).joined(separator: " ")
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        if s.count > 100 { s = String(s.prefix(100)).trimmingCharacters(in: .whitespaces) }
        return s.isEmpty ? "Untitled" : s
    }

    /// Obsidian tags cannot hold spaces or "&": "Brain & body" → "brain-body".
    public static func tag(_ t: String) -> String {
        let parts = Shelf.fold(t).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return parts.joined(separator: "-")
    }

    /// One unique name per live card (a second "Notes" becomes "Notes (2)"),
    /// oldest first so a name never moves to another card between exports.
    public static func names(_ library: Library) -> [String: String] {
        var taken: [String: Int] = [:]
        var out: [String: String] = [:]
        for v in library.live.sorted(by: { $0.savedAt != $1.savedAt ? $0.savedAt < $1.savedAt : $0.id < $1.id }) {
            let base = fileName(v.title.isEmpty ? v.url : v.title)
            let key = base.lowercased()
            let n = (taken[key] ?? 0) + 1
            taken[key] = n
            out[v.id] = n == 1 ? base : "\(base) (\(n))"
        }
        return out
    }

    private static let day: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private static func yaml(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// [[Title]] he wrote in the app points at the card's title; the note is
    /// named after the file name, which can differ — so it is rewritten to
    /// [[file name|Title]] wherever they differ.
    static func relink(_ text: String, byTitle: [String: String]) -> String {
        guard text.contains("[[") else { return text }
        let re = try! NSRegularExpression(pattern: #"\[\[([^\[\]\|\n]+)(\|[^\[\]\n]*)?\]\]"#)
        let ns = text as NSString
        var out = text
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let title = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            guard let file = byTitle[Shelf.fold(title)], file != title else { continue }
            let shown = m.range(at: 2).location != NSNotFound ? String(ns.substring(with: m.range(at: 2)).dropFirst()) : title
            out = (out as NSString).replacingCharacters(in: m.range, with: "[[\(file)|\(shown)]]")
        }
        return out
    }

    public static func note(for v: Video, in library: Library, names: [String: String]) -> Note {
        var byTitle: [String: String] = [:]
        for x in library.live { if let n = names[x.id] { byTitle[Shelf.fold(x.title)] = byTitle[Shelf.fold(x.title)] ?? n } }
        var y: [String] = ["---"]
        y.append("title: \(yaml(v.title))")
        y.append("url: \(yaml(v.url))")
        if !v.channel.isEmpty { y.append("channel: \(yaml(v.channel))") }
        y.append("kind: \(v.kind.rawValue)")
        if let s = v.seconds { y.append("length: \(yaml(v.kind.isTimed ? (Clock.badge(s) ?? "") : "\(max(1, s / 60)) min read"))") }
        y.append("saved: \(day.string(from: v.savedAt))")
        if let w = v.watchedAt { y.append("\(v.kind.isTimed ? "watched" : "read"): \(day.string(from: w))") }
        let tags = ["watchlater"] + v.tags.map(tag).filter { !$0.isEmpty }
        y.append("tags: [\(tags.joined(separator: ", "))]")
        y.append("source: AMS WatchLater")
        y.append("---")

        var b: [String] = ["", "# \(v.title.isEmpty ? v.url : v.title)", ""]
        var line = "[\(openWord(v))](\(v.url))"
        if !v.tags.isEmpty {
            line += " · " + v.tags.map { "[[\(topicPath($0))|\($0)]]" }.joined(separator: " · ")
        }
        b.append(line)
        if !v.note.isEmpty { b += ["", "> \(v.note)"] }
        if !v.blurb.isEmpty { b += ["", v.blurb] }

        if let d = v.digest {
            b += ["", "## Summary", "", d.summary]
            if !d.points.isEmpty { b += ["", "### Key points", ""] + d.points.map { "- \($0)" } }
            if !d.questions.isEmpty {
                b += ["", "### Check yourself", ""]
                for q in d.questions { b.append("- **\(q.question)** — \(q.answer)") }
            }
            b += ["", "*Made by Apple Intelligence on \(day.string(from: d.madeAt)).*"]
        }
        let marks = v.sortedMarks
        if !marks.isEmpty {
            b += ["", "## Marks", ""]
            for m in marks {
                if let s = m.seconds, let badge = Clock.badge(s), let u = v.url(at: s) {
                    b.append("- [\(badge)](\(u.absoluteString)) \(m.text)")
                } else {
                    b.append("- \(m.text)")
                }
            }
        }
        let body = v.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { b += ["", "## Notes", "", relink(body, byTitle: byTitle)] }
        let conn = Connections.all(v, in: library).compactMap { l in names[l.item.id] }
        if !conn.isEmpty { b += ["", "## Connected", ""] + conn.map { "- [[\($0)]]" } }
        return Note(path: "\(names[v.id] ?? fileName(v.title)).md", text: (y + b).joined(separator: "\n") + "\n")
    }

    static func topicPath(_ name: String) -> String { "Topics/\(fileName(name))" }

    static func openWord(_ v: Video) -> String {
        switch v.kind {
        case .video: return v.videoId != nil ? "Watch on YouTube" : "Watch"
        case .podcast: return "Listen"
        case .article, .page: return "Read"
        }
    }

    /// Every note: the cards, a note per topic, and an index.
    public static func all(_ library: Library) -> [Note] {
        let names = names(library)
        var notes = library.live.map { note(for: $0, in: library, names: names) }
        let topics = Topics.all(library)
        for t in topics {
            var b = ["---", "tags: [watchlater, watchlater-topic]", "source: AMS WatchLater", "---", "", "# \(t.name)", "", t.summary, ""]
            let waiting = t.items.filter(\.isOpen), done = t.items.filter { !$0.isOpen }
            if !waiting.isEmpty { b += ["## Waiting", ""] + waiting.compactMap { names[$0.id].map { "- [[\($0)]]" } } + [""] }
            if !done.isEmpty { b += ["## In the Library", ""] + done.compactMap { names[$0.id].map { "- [[\($0)]]" } } + [""] }
            let near = Connections.relatedTopics(t, in: library)
            if !near.isEmpty { b += ["## Related topics", ""] + near.map { "- [[\(topicPath($0.topic.name))|\($0.topic.name)]]" } + [""] }
            notes.append(Note(path: "\(topicPath(t.name)).md", text: b.joined(separator: "\n")))
        }
        var i = ["---", "tags: [watchlater]", "source: AMS WatchLater", "---", "", "# WatchLater", ""]
        if !topics.isEmpty { i += ["## Topics", ""] + topics.map { "- [[\(topicPath($0.name))|\($0.name)]] — \($0.items.count)" } + [""] }
        let done = library.live.filter { $0.watchedAt != nil }.sorted { ($0.watchedAt ?? .distantPast) > ($1.watchedAt ?? .distantPast) }
        if !done.isEmpty { i += ["## In the Library", ""] + done.compactMap { names[$0.id].map { "- [[\($0)]]" } } + [""] }
        let open = library.open
        if !open.isEmpty { i += ["## Waiting", ""] + open.compactMap { names[$0.id].map { "- [[\($0)]]" } } + [""] }
        notes.append(Note(path: "WatchLater.md", text: i.joined(separator: "\n")))
        return notes
    }

    // MARK: Never overwrite his edits

    /// A short fingerprint of a note's text (FNV-1a), kept in the export
    /// folder's manifest to recognise "the app wrote this and nobody changed it".
    public static func fingerprint(_ text: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in text.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return String(h, radix: 16)
    }

    public enum Step: Equatable { case write, same, keepHis }

    /// What to do with each note: write it when the file is new or is still
    /// exactly what the app wrote last time; leave it when he has changed it in
    /// Obsidian (or it was not the app's); skip it when nothing changed.
    public static func plan(_ note: Note, onDisk: String?, manifest: [String: String]) -> Step {
        guard let onDisk else { return .write }
        if onDisk == note.text { return .same }
        if let written = manifest[note.path], written == fingerprint(onDisk) { return .write }
        return .keepHis
    }
}

/// Everything in one table — Numbers or Excel open it.
public enum Spreadsheet {
    public static func csv(_ library: Library) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
        func cell(_ s: String) -> String {
            s.contains(where: { ",\"\n\r".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        var rows = ["Title,Link,Channel,Kind,Minutes,Saved,Watched or read,Tags,Marks,Note,Summary"]
        for v in library.live.sorted(by: { $0.savedAt > $1.savedAt }) {
            rows.append([v.title, v.url, v.channel, v.kind.rawValue,
                         v.seconds.map { String(Int((Double($0) / 60).rounded())) } ?? "",
                         f.string(from: v.savedAt), v.watchedAt.map { f.string(from: $0) } ?? "",
                         v.tags.joined(separator: "; "), String(v.marks.count), v.note, v.digest?.summary ?? ""]
                .map(cell).joined(separator: ","))
        }
        // The byte-order mark tells Excel on the Mac the file is UTF-8 — without
        // it "hjärnans" opens as "hjÃ¤rnans". Numbers does not mind it.
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }
}
