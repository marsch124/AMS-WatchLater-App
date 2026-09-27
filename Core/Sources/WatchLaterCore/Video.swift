import Foundation

/// One saved video. The field names are the web app's, so its `watchlater.json`
/// reads straight in — `modifiedAt` is the one addition, and it is what lets
/// two devices agree on who changed a card last.
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
    public var note: String
    public var modifiedAt: Date

    public init(id: String = Video.newID(), videoId: String?, url: String, title: String,
                channel: String = "", seconds: Int? = nil, savedAt: Date = Date(),
                isShort: Bool = false, tags: [String] = [], note: String = "") {
        self.id = id
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
    }

    // MARK: What the card says

    public var isOpen: Bool { watchedAt == nil && deletedAt == nil }
    public var isPinned: Bool { pinnedAt != nil }
    public var isTogether: Bool { togetherAt != nil }

    /// A Short is one saved from a /shorts/ link — or anything a minute or
    /// less, which catches the ones saved before that was recorded.
    public var countsAsShort: Bool {
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
        guard let v = videoId else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(v)/mqdefault.jpg")
    }

    public var watchURL: URL? { URL(string: url) }
}

/// The whole list, as it sits in the file.
public struct Library: Codable, Equatable {
    public var version: String
    public var schema: Int
    public var savedAt: Date
    public var items: [Video]

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
