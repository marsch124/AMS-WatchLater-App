import Foundation

/// Everything about a YouTube link or page that can be worked out without a
/// network: pure functions over strings, so every one of them has a test.
public enum YouTube {

    // MARK: Links

    /// The eleven-character id, from any of the shapes a link comes in.
    public static func videoId(in url: String) -> String? {
        let patterns = [
            #"[?&]v=([A-Za-z0-9_-]{11})"#,
            #"youtu\.be/([A-Za-z0-9_-]{11})"#,
            #"/shorts/([A-Za-z0-9_-]{11})"#,
            #"/live/([A-Za-z0-9_-]{11})"#,
            #"/embed/([A-Za-z0-9_-]{11})"#,
        ]
        for p in patterns {
            if let m = url.firstMatch(of: p) { return m }
        }
        return nil
    }

    public static func playlistId(in url: String) -> String? {
        url.firstMatch(of: #"[?&]list=([A-Za-z0-9_-]+)"#)
    }

    public static func isShortLink(_ url: String) -> Bool {
        url.range(of: #"/shorts/[A-Za-z0-9_-]{11}"#, options: .regularExpression) != nil
    }

    /// Only a BARE playlist link fans out. A watch link that happens to carry
    /// a list= is one video with company.
    public static func isBarePlaylist(_ url: String) -> Bool {
        videoId(in: url) == nil && playlistId(in: url) != nil
    }

    public static func watchURL(for id: String) -> String {
        "https://www.youtube.com/watch?v=\(id)"
    }

    /// A pasted window of tabs: every link in the text, in order, once each.
    public static func links(in text: String) -> [String] {
        let re = try! NSRegularExpression(pattern: #"https?://[^\s<>"']+"#)
        let ns = text as NSString
        var seen = Set<String>()
        var out: [String] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var s = ns.substring(with: m.range)
            while let last = s.last, ").,;".contains(last) { s.removeLast() }
            if seen.insert(s).inserted { out.append(s) }
        }
        return out
    }

    /// One link that plays a set, in order, on any screen — this is how an
    /// evening reaches the television or his wife without them having the app.
    public static func playlistLink(for ids: [String]) -> String {
        "https://www.youtube.com/watch_videos?video_ids=" + ids.joined(separator: ",")
    }

    // MARK: Pages

    public struct Meta: Equatable {
        public var title: String?
        public var channel: String?
        public var seconds: Int?
        public init(title: String? = nil, channel: String? = nil, seconds: Int? = nil) {
            self.title = title; self.channel = channel; self.seconds = seconds
        }
    }

    /// oEmbed is the reliable, keyless source for title and channel.
    public static func parseOEmbed(_ data: Data) -> Meta {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Meta() }
        return Meta(title: j["title"] as? String, channel: j["author_name"] as? String)
    }

    /// The watch page is the only keyless source of the length.
    public static func parseWatchPage(_ html: String) -> Meta {
        var m = Meta()
        if let s = html.firstMatch(of: #""lengthSeconds":"(\d+)""#) { m.seconds = Int(s) }
        if m.seconds == nil, let iso = html.firstMatch(of: #"itemprop="duration"\s+content="([^"]+)""#) {
            m.seconds = isoToSeconds(iso)
        }
        if let t = html.firstMatch(of: #"<meta\s+name="title"\s+content="([^"]*)""#) { m.title = decodeEntities(t) }
        if let c = html.firstMatch(of: #""ownerChannelName":"([^"]+)""#) { m.channel = decodeEntities(c) }
        return m
    }

    public struct PlaylistRow: Equatable {
        public var id: String
        public var seconds: Int?
        public init(id: String, seconds: Int?) { self.id = id; self.seconds = seconds }
    }

    public static let playlistMax = 60

    /// Each row of the playlist page carries the video's id AND its little
    /// duration badge, so one page read replaces a one-megabyte watch page per
    /// video. The badge comes BEFORE its own row's id, so a row's length is the
    /// last badge between the previous row and this one — taking the first badge
    /// after the id hands every video the next one's length.
    public static func parsePlaylistPage(_ html: String) -> [PlaylistRow] {
        let rowRe = try! NSRegularExpression(
            pattern: #""contentId":"([A-Za-z0-9_-]{11})","contentType":"LOCKUP_CONTENT_TYPE_VIDEO""#)
        let badgeRe = try! NSRegularExpression(pattern: #""text":"(\d{1,2}:\d{2}(?::\d{2})?)""#)
        let ns = html as NSString
        let rows = rowRe.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var out: [PlaylistRow] = []
        var seen = Set<String>()
        var from = 0
        for r in rows {
            if out.count >= playlistMax { break }
            let id = ns.substring(with: r.range(at: 1))
            let stretch = NSRange(location: from, length: r.range.location - from)
            from = r.range.location
            if !seen.insert(id).inserted { continue }
            let badge = badgeRe.matches(in: html, range: stretch).last.map { ns.substring(with: $0.range(at: 1)) }
            out.append(PlaylistRow(id: id, seconds: badge.flatMap(clockToSeconds)))
        }
        if out.isEmpty {
            // A page built some other way: every video id on it, lengths later.
            let anyRe = try! NSRegularExpression(pattern: #""videoId":"([A-Za-z0-9_-]{11})""#)
            for m in anyRe.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                if seen.insert(id).inserted { out.append(PlaylistRow(id: id, seconds: nil)) }
                if out.count >= playlistMax { break }
            }
        }
        return out
    }

    // MARK: Little helpers

    public static func isoToSeconds(_ iso: String) -> Int? {
        let re = try! NSRegularExpression(pattern: #"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$"#)
        let ns = iso as NSString
        guard let m = re.firstMatch(in: iso, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func part(_ i: Int) -> Int {
            let r = m.range(at: i)
            return r.location == NSNotFound ? 0 : Int(ns.substring(with: r)) ?? 0
        }
        return part(1) * 3600 + part(2) * 60 + part(3)
    }

    public static func clockToSeconds(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    public static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// His own words, but two spellings of one word would split a filter in
    /// half: trimmed, de-duplicated case-blind, capped at twelve.
    public static func cleanTags(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for t in raw {
            let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty, s.count <= 30, seen.insert(s.lowercased()).inserted else { continue }
            out.append(s)
            if out.count == 12 { break }
        }
        return out
    }
}

extension String {
    /// The first capture group of the first match, or nil.
    func firstMatch(of pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = self as NSString
        guard let m = re.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
}
