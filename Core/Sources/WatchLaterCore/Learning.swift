import Foundation

/// What Apple Intelligence made of a video: a few sentences, the key points
/// and questions to check yourself with.
public struct Digest: Codable, Equatable, Hashable {
    public struct Question: Codable, Equatable, Hashable {
        public var question: String
        public var answer: String
        public init(question: String, answer: String) { self.question = question; self.answer = answer }
    }
    public var summary: String
    public var points: [String]
    public var questions: [Question]
    public var madeAt: Date
    public init(summary: String, points: [String], questions: [Question], madeAt: Date = Date()) {
        self.summary = summary; self.points = points; self.questions = questions; self.madeAt = madeAt
    }
}

extension Digest {
    /// What the app asks the model to write — plain text in this shape, read
    /// back by `parse`. (Plain text, because Apple's gentler guardrails for
    /// summarising his own material only apply to plain text: with the strict
    /// ones it refused a swimming-exercise video as "sensitive", 2026-09-28.)
    public static let form = """
    Answer in exactly this form, with these three headings written exactly like this:
    SUMMARY:
    three to five plain sentences on what the video is about and what it teaches
    KEY POINTS:
    - one short sentence per point, three to six points
    QUESTIONS:
    Q: a question about something the video explains
    A: its short answer, as the video gives it
    (three or four Q and A pairs)
    """

    /// Reads the model's answer. It decorates freely — "### SUMMARY:",
    /// "**Key points**", "*   point", "Q:  " — so every line is cleaned
    /// before it is judged. Nil when there is no summary to show.
    public static func parse(_ text: String, madeAt: Date = Date()) -> Digest? {
        enum Part { case none, summary, points, questions }
        var part = Part.none
        var summary: [String] = [], points: [String] = []
        var questions: [Question] = []
        var pendingQ: String?

        func strip(_ line: String) -> String {
            var l = line.trimmingCharacters(in: .whitespaces)
            while let f = l.first, "#*_>".contains(f) { l.removeFirst() }
            while let e = l.last, "*_".contains(e) { l.removeLast() }
            return l.trimmingCharacters(in: .whitespaces)
        }
        func heading(_ l: String) -> Part? {
            let h = l.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            switch h {
            case "SUMMARY": return .summary
            case "KEY POINTS", "KEYPOINTS", "POINTS": return .points
            case "QUESTIONS": return .questions
            default: return nil
            }
        }
        func after(_ l: String, _ prefixes: [String]) -> String? {
            for p in prefixes where l.uppercased().hasPrefix(p) {
                // Only the front: the answer's own full stop stays.
                return String(String(l.dropFirst(p.count)).drop { ": .)*".contains($0) })
            }
            return nil
        }

        for raw in text.components(separatedBy: .newlines) {
            let l = strip(raw)
            guard !l.isEmpty else { continue }
            // "SUMMARY: the video…" on one line.
            if let colon = l.firstIndex(of: ":"), let h = heading(String(l[..<colon])) {
                part = h
                let rest = strip(String(l[l.index(after: colon)...]))
                if !rest.isEmpty, h == .summary { summary.append(rest) }
                continue
            }
            if let h = heading(l) { part = h; continue }
            switch part {
            // It sometimes leaves the SUMMARY heading out and simply starts
            // (seen 2026-09-28): what comes before the first heading is it.
            case .none, .summary: summary.append(l)
            case .points:
                var p = l
                if let f = p.first, "-•*".contains(f) { p.removeFirst() }
                if let dot = p.firstIndex(of: "."), p[..<dot].allSatisfy(\.isNumber), !p[..<dot].isEmpty {
                    p = String(p[p.index(after: dot)...])
                }
                p = p.trimmingCharacters(in: .whitespaces)
                if !p.isEmpty { points.append(p) }
            case .questions:
                if let q = after(l, ["Q:", "Q.", "QUESTION:"]) ?? after(l, ["Q1", "Q2", "Q3", "Q4", "Q5"]) {
                    pendingQ = q
                } else if let a = after(l, ["A:", "A.", "ANSWER:"]) ?? after(l, ["A1", "A2", "A3", "A4", "A5"]), let q = pendingQ {
                    questions.append(Question(question: q, answer: a)); pendingQ = nil
                }
            }
        }
        let s = summary.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        // Asked for three to six points, it sometimes gives eight: a short
        // list is the point, so the first six stay (and four questions).
        return Digest(summary: s, points: Array(points.prefix(6)), questions: Array(questions.prefix(4)), madeAt: madeAt)
    }
}

/// Old marks come back to be looked at again, at widening gaps — a day, three
/// days, a week, three weeks, two months, half a year. "I remember" moves a
/// mark one gap further; "Again" starts it over. A few a day, never a pile.
public enum Review {
    public static let gapsInDays = [1, 3, 7, 21, 60, 180]
    public static let perDay = 5

    public struct Due: Identifiable, Equatable {
        public let item: Video
        public let mark: Mark
        public var id: String { mark.id }
    }

    /// When a mark is next up: the gap for its step, counted from the last
    /// look — or from when he wrote it.
    public static func next(_ m: Mark) -> Date {
        let step = min(max(m.reviewStep ?? 0, 0), gapsInDays.count - 1)
        return (m.reviewedAt ?? m.createdAt).addingTimeInterval(Double(gapsInDays[step]) * 86_400)
    }

    /// Marks with words in them whose day has come, the longest-waiting first,
    /// at most `perDay`.
    public static func due(_ library: Library, now: Date = Date(), limit: Int = Review.perDay) -> [Due] {
        var out: [(Due, Date)] = []
        for v in library.live {
            for m in v.marks where !m.text.trimmingCharacters(in: .whitespaces).isEmpty {
                let when = next(m)
                if when <= now { out.append((Due(item: v, mark: m), when)) }
            }
        }
        return out.sorted { $0.1 < $1.1 }.prefix(limit).map(\.0)
    }

    public static func remembered(_ m: Mark, now: Date = Date()) -> Mark {
        var x = m
        x.reviewStep = min((m.reviewStep ?? 0) + 1, gapsInDays.count - 1)
        x.reviewedAt = now
        return x
    }

    public static func again(_ m: Mark, now: Date = Date()) -> Mark {
        var x = m
        x.reviewStep = 0
        x.reviewedAt = now
        return x
    }
}

/// The on-device model reads a few thousand words at a time, so a long
/// transcript is cut into pieces at line breaks, each read on its own.
public enum Reading {
    public static let wordsPerPiece = 1_100
    /// Below this the model has too little to go on and makes things up — from
    /// three short lines about Raycast it described "a game feature" (2026-09-28).
    public static let fewestWords = 120

    public static func wordCount(_ lines: [Transcript.Line]) -> Int {
        lines.reduce(0) { $0 + $1.s.split(separator: " ").count }
    }

    public static func pieces(_ lines: [Transcript.Line], wordsPerPiece: Int = Reading.wordsPerPiece) -> [String] {
        var out: [String] = []
        var current: [String] = []
        var count = 0
        for l in lines {
            let n = l.s.split(separator: " ").count
            if count + n > wordsPerPiece, !current.isEmpty {
                out.append(current.joined(separator: " "))
                current = []; count = 0
            }
            current.append(l.s); count += n
        }
        if !current.isEmpty { out.append(current.joined(separator: " ")) }
        return out
    }
}

/// "Find more": a YouTube search built from a topic or a card's title.
public enum Research {
    /// The title's telling words — without "minutes", "the", episode numbers.
    public static func query(for v: Video) -> String {
        let words = v.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !Connections.quiet.contains(Shelf.fold($0)) && Int($0) == nil }
        let q = words.prefix(6).joined(separator: " ")
        return q.isEmpty ? v.title : q
    }

    public static func youTube(_ query: String) -> URL? {
        var c = URLComponents(string: "https://www.youtube.com/results")!
        c.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return c.url
    }
}
