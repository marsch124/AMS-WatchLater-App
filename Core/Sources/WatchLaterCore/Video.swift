import Foundation

/// What kind of thing a saved link is. Decides the words on the card ("Watched"
/// or "Read"), whether a mark carries a time, and which picture to show.
public enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case video, article, podcast, page
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .video:   return "Videos"
        case .article: return "Articles"
        case .podcast: return "Podcasts"
        case .page:    return "Pages"
        }
    }

    /// Videos and podcasts play; a mark on them remembers a moment.
    public var isTimed: Bool { self == .video || self == .podcast }
}

/// A moment worth keeping: "at 12:34 — the bit about sleep". On an article or
/// a page there is no time, and a mark is a quote or a thought instead.
public struct Mark: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var seconds: Int?
    public var text: String
    public var createdAt: Date
    // Since 0.6 — Review: when he last looked at it again, and how far along
    // the widening gaps it is (see `Review`). Absent in older files.
    public var reviewedAt: Date?
    public var reviewStep: Int?

    public init(id: String = Video.newID(), seconds: Int?, text: String, createdAt: Date = Date()) {
        self.id = id
        self.seconds = seconds
        self.text = text
        self.createdAt = createdAt
    }
}

/// One saved thing — a video, an article, a podcast or any page. (The type keeps
/// its first name, `Video`, so the file the old app wrote still reads straight in.)
/// The field names are the web app's; `modifiedAt` is what lets two devices agree
/// on who changed a card last.
public struct Video: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var videoId: String?
    public var url: String
    public var title: String
    public var channel: String
    public var seconds: Int?
    public var savedAt: Date
    public var watchedAt: Date?
    public var keptAt: Date?
    public var isShort: Bool
    public var pinnedAt: Date?
    public var togetherAt: Date?
    /// A tombstone, not a deletion: the card stays for Undo and so the other
    /// device learns about the removal. Read the list through `Library.live`.
    public var deletedAt: Date?
    public var startedAt: Date?
    public var answeredAt: Date?
    public var checkedAt: Date?
    public var goneAt: Date?
    public var tags: [String]
    /// The one line on the card.
    public var note: String
    public var modifiedAt: Date

    // Since 0.2 — the knowledge-base fields.
    public var kind: ItemKind
    /// Moments and quotes, in the order they happen (see `sortedMarks`).
    public var marks: [Mark]
    /// The long note: Markdown, as much as he likes.
    public var body: String
    /// A page's own picture (og:image). YouTube pictures come from the video id.
    public var imageURL: String?
    /// A page's own one-paragraph description (og:description).
    public var blurb: String

    // Since 0.5 — connecting.
    /// Cards this one links to, by id (made with "Link to…"). Links also come
    /// from `[[Title]]` in the note; see `Connections`.
    public var links: [String]

    // Since 0.6 — learning more.
    /// A summary, key points and questions, made on one of his devices. Kept
    /// on the card so a device without Apple Intelligence sees it too.
    public var digest: Digest?

    public init(id: String = Video.newID(), videoId: String?, url: String, title: String,
                channel: String = "", seconds: Int? = nil, savedAt: Date = Date(),
                isShort: Bool = false, tags: [String] = [], note: String = "",
                kind: ItemKind? = nil) {
        self.id = id
        self.kind = kind ?? (videoId != nil ? .video : .page)
        self.marks = []
        self.body = ""
        self.imageURL = nil
        self.blurb = ""
        self.links = []
        self.videoId = videoId
        self.url = url
        self.title = title
        self.channel = channel
        self.seconds = seconds
        self.savedAt = savedAt
        self.isShort = isShort
        self.tags = tags
        self.note = note
        self.modifiedAt = savedAt
    }

    /// Same shape as the web app's ids, so old and new cards look alike.
    public static func newID() -> String {
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let salt = String((0..<5).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        return stamp + salt
    }

    // Old files carry none of the newer fields; each one falls back quietly.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        videoId = try c.decodeIfPresent(String.self, forKey: .videoId)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        channel = try c.decodeIfPresent(String.self, forKey: .channel) ?? ""
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds)
        savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        watchedAt = try c.decodeIfPresent(Date.self, forKey: .watchedAt)
        keptAt = try c.decodeIfPresent(Date.self, forKey: .keptAt)
        isShort = try c.decodeIfPresent(Bool.self, forKey: .isShort) ?? false
        pinnedAt = try c.decodeIfPresent(Date.self, forKey: .pinnedAt)
        togetherAt = try c.decodeIfPresent(Date.self, forKey: .togetherAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        answeredAt = try c.decodeIfPresent(Date.self, forKey: .answeredAt)
        checkedAt = try c.decodeIfPresent(Date.self, forKey: .checkedAt)
        goneAt = try c.decodeIfPresent(Date.self, forKey: .goneAt)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? savedAt
        kind = try c.decodeIfPresent(ItemKind.self, forKey: .kind) ?? (videoId != nil ? .video : .page)
        marks = try c.decodeIfPresent([Mark].self, forKey: .marks) ?? []
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        blurb = try c.decodeIfPresent(String.self, forKey: .blurb) ?? ""
        links = try c.decodeIfPresent([String].self, forKey: .links) ?? []
        digest = try c.decodeIfPresent(Digest.self, forKey: .digest)
    }

    // MARK: What the card says

    public var isOpen: Bool { watchedAt == nil && deletedAt == nil }
    public var isPinned: Bool { pinnedAt != nil }
    public var isTogether: Bool { togetherAt != nil }

    /// A Short is one saved from a /shorts/ link — or anything a minute or
    /// less, which catches the ones saved before that was recorded.
    public var countsAsShort: Bool {
        guard kind == .video else { return false }
        if isShort { return true }
        if let s = seconds { return s <= 60 }
        return false
    }

    /// Three months on the list without being kept is the nudge to decide.
    public static let staleAfterDays = 90

    public func isStale(now: Date = Date()) -> Bool {
        guard isOpen, keptAt == nil else { return false }
        return now.timeIntervalSince(savedAt) > Double(Video.staleAfterDays) * 86_400
    }

    /// Opened once, never answered — the card asks "Did you finish it?".
    public var awaitsAnswer: Bool { isOpen && startedAt != nil && answeredAt == nil }

    public var thumbnailURL: URL? {
        if let v = videoId { return URL(string: "https://i.ytimg.com/vi/\(v)/mqdefault.jpg") }
        return imageURL.flatMap(URL.init(string:))
    }

    /// The name a picture is kept under on this device.
    public var thumbKey: String { videoId ?? id }

    public var watchURL: URL? { URL(string: url) }

    /// Is there anything of HIS on this card — the test for "knowledge".
    public var hasNotes: Bool {
        !note.isEmpty || !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !marks.isEmpty
    }

    /// Timed marks by their moment, then the untimed ones by when he wrote them.
    public var sortedMarks: [Mark] {
        marks.sorted { a, b in
            switch (a.seconds, b.seconds) {
            case let (x?, y?): return x == y ? a.createdAt < b.createdAt : x < y
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.createdAt < b.createdAt
            }
        }
    }

    /// The same video, starting at that second. A YouTube link carries `t=`;
    /// anything else simply opens at the start.
    public func url(at seconds: Int?) -> URL? {
        guard let s = seconds, s > 0, let id = videoId else { return watchURL }
        return URL(string: "https://www.youtube.com/watch?v=\(id)&t=\(s)s")
    }

    /// Done means Watched for things that play and Read for things to read.
    public var doneWord: String { kind.isTimed ? "Watched" : "Read" }
}

/// A search he wants to come back to — one tap in Find runs it again.
public struct SavedSearch: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var query: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?
    public init(id: String = Video.newID(), query: String, createdAt: Date = Date()) {
        self.id = id; self.query = query; self.createdAt = createdAt; self.modifiedAt = createdAt
    }
}

/// The whole list, as it sits in the file.
public struct Library: Codable, Equatable {
    public var version: String
    public var schema: Int
    public var savedAt: Date
    public var items: [Video]
    /// Since 0.4 — kept in the same file so they travel between devices.
    public var searches: [SavedSearch] = []

    public init(version: String = "", items: [Video] = []) {
        self.version = version
        self.schema = 1
        self.savedAt = Date()
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        items = try c.decodeIfPresent([Video].self, forKey: .items) ?? []
        searches = try c.decodeIfPresent([SavedSearch].self, forKey: .searches) ?? []
    }

    /// The saved searches still in use, oldest first (the order he made them).
    public var liveSearches: [SavedSearch] {
        searches.filter { $0.deletedAt == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Everything that has not been binned.
    public var live: [Video] { items.filter { $0.deletedAt == nil } }
    public var open: [Video] { items.filter { $0.isOpen } }

    /// Tombstones live long enough for a device that was off for a month to
    /// hear about the removal, then go.
    public static let tombstoneDays = 30

    public mutating func purgeTombstones(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(Library.tombstoneDays) * 86_400)
        items.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff }
        searches.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff }
    }

    /// Two copies of the list become one: a card is taken from whichever side
    /// changed it last, and a card only one side knows about is kept. A removal
    /// is a change like any other, so a bin on the phone cannot come back to
    /// life from the Mac.
    public static func merged(_ a: Library, _ b: Library) -> Library {
        var byID: [String: Video] = [:]
        var order: [String] = []
        for v in a.items { byID[v.id] = v; order.append(v.id) }
        for v in b.items {
            if let mine = byID[v.id] {
                if v.modifiedAt > mine.modifiedAt { byID[v.id] = v }
            } else {
                byID[v.id] = v
                order.append(v.id)
            }
        }
        var out = Library(version: a.version.isEmpty ? b.version : a.version)
        out.schema = max(a.schema, b.schema)
        out.savedAt = max(a.savedAt, b.savedAt)
        out.items = order.compactMap { byID[$0] }.sorted { $0.savedAt > $1.savedAt }
        // Saved searches merge the same way: later change wins, a removal is a change.
        var sById: [String: SavedSearch] = [:]
        for q in a.searches + b.searches {
            if let mine = sById[q.id], mine.modifiedAt >= q.modifiedAt { continue }
            sById[q.id] = q
        }
        out.searches = sById.values.sorted { $0.createdAt < $1.createdAt }
        return out
    }

    public func index(ofVideo videoId: String) -> Int? {
        items.firstIndex { $0.videoId == videoId }
    }
}

// MARK: - JSON, the way the web app wrote it

public extension JSONDecoder {
    /// Reads ISO 8601 with or without fractional seconds — the web app wrote
    /// `2026-09-26T18:44:12.289Z`, Foundation writes without the millis.
    static let watchLater: JSONDecoder = {
        let d = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFraction.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "not a date: \(s)")
        }
        return d
    }()
}

public extension JSONEncoder {
    static let watchLater: JSONEncoder = {
        let e = JSONEncoder()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
