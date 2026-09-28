import Foundation

/// What was said in a video, line by line with the moment it was said.
///
/// YouTube no longer hands caption files to anything but its own player (the
/// caption URL answers empty and the transcript endpoint says "precondition
/// failed" — checked 2026-09-28), so the app lets its hidden player switch
/// subtitles on and catches the file the player downloads. This is the model
/// side: reading that file, and keeping it.
public struct Transcript: Codable, Equatable {
    public struct Line: Codable, Equatable, Hashable {
        /// Milliseconds into the video.
        public var t: Int
        /// The words.
        public var s: String
        public init(t: Int, s: String) { self.t = t; self.s = s }
        public var seconds: Int { t / 1000 }
    }

    public var videoId: String
    public var lines: [Line]
    public var fetchedAt: Date

    public init(videoId: String, lines: [Line], fetchedAt: Date = Date()) {
        self.videoId = videoId
        self.lines = lines
        self.fetchedAt = fetchedAt
    }

    public var isEmpty: Bool { lines.isEmpty }

    /// All the words, for counting and quick "does it mention" checks.
    public var fullText: String { lines.map(\.s).joined(separator: " ") }

    /// Reads YouTube's caption file (the "json3" the player downloads): a list
    /// of timed events, each with pieces of words; events marked `aAppend` are
    /// only line breaks. Automatic captions come word by word — they are joined
    /// back into the lines the player shows.
    public static func parseJSON3(_ data: Data) -> [Line] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else { return [] }
        var out: [Line] = []
        for e in events {
            if (e["aAppend"] as? Int) == 1 { continue }
            guard let segs = e["segs"] as? [[String: Any]] else { continue }
            let raw = segs.compactMap { $0["utf8"] as? String }.joined()
            let text = raw.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let t = (e["tStartMs"] as? Int) ?? Int((e["tStartMs"] as? Double) ?? 0)
            out.append(Line(t: t, s: YouTube.decodeEntities(text)))
        }
        return out.sorted { $0.t < $1.t }
    }

    /// Whatever the player handed over: JSON (json3) or the older XML (srv3,
    /// `<p t="ms" d="ms">words</p>`). Either way, timed lines.
    public static func parse(_ data: Data) -> [Line] {
        let head = String(decoding: data.prefix(64), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if head.hasPrefix("{") { return parseJSON3(data) }
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        let re = try! NSRegularExpression(pattern: #"(?s)<p\s+t="(\d+)"[^>]*>(.*?)</p>"#)
        let ns = xml as NSString
        return re.matches(in: xml, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let t = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let text = ns.substring(with: m.range(at: 2))
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : Line(t: t, s: YouTube.decodeEntities(text))
        }
    }

    /// Every line that mentions the words, accent-blind — for a card's own
    /// "What was said" search.
    public func lines(matching query: String) -> [Line] {
        let needle = Shelf.fold(query)
        guard needle.count >= 2 else { return [] }
        return lines.filter { Shelf.fold($0.s).contains(needle) }
    }
}

/// One small file per video, beside the list, so a transcript fetched on the Mac
/// is there on the iPhone too. A video with no captions gets a marker instead,
/// so it is not asked again every time — only after a week.
public struct TranscriptShelf {
    public let folder: URL
    public init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    struct Marker: Codable { var none: Bool; var triedAt: Date }

    public static let retryAfterDays = 7

    private func url(_ videoId: String) -> URL { folder.appendingPathComponent("\(videoId).json") }

    public func read(_ videoId: String) -> Transcript? {
        guard let data = try? Data(contentsOf: url(videoId)),
              let t = try? JSONDecoder.watchLater.decode(Transcript.self, from: data), !t.isEmpty else { return nil }
        return t
    }

    public func write(_ t: Transcript) {
        guard let data = try? JSONEncoder.watchLater.encode(t) else { return }
        try? data.write(to: url(t.videoId), options: .atomic)
    }

    /// Remember that a video had no captions (or the player gave none).
    public func markNone(_ videoId: String, now: Date = Date()) {
        guard let data = try? JSONEncoder.watchLater.encode(Marker(none: true, triedAt: now)) else { return }
        try? data.write(to: url(videoId), options: .atomic)
    }

    /// Worth asking the player for this video now?
    public func needsFetch(_ videoId: String, now: Date = Date()) -> Bool {
        guard let data = try? Data(contentsOf: url(videoId)) else { return true }
        if let t = try? JSONDecoder.watchLater.decode(Transcript.self, from: data), !t.isEmpty { return false }
        if let m = try? JSONDecoder.watchLater.decode(Marker.self, from: data) {
            return now.timeIntervalSince(m.triedAt) > Double(TranscriptShelf.retryAfterDays) * 86_400
        }
        return true
    }

    /// Every transcript on the shelf, by video id.
    public func all() -> [String: Transcript] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var out: [String: Transcript] = [:]
        for f in files where f.pathExtension == "json" {
            let id = f.deletingPathExtension().lastPathComponent
            if let t = read(id) { out[id] = t }
        }
        return out
    }
}
