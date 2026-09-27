import Foundation

/// Any link that is not YouTube: an article, a podcast episode, a page. Every
/// site announces itself in the same few meta tags (Open Graph), so one reader
/// covers nearly all of them. Pure functions over the HTML, all tested.
public enum Page {

    public struct Meta: Equatable {
        public var title: String?
        public var site: String?
        public var imageURL: String?
        public var blurb: String?
        public var kind: ItemKind = .page
        /// A podcast's length, or an article's reading time at 230 words a minute.
        public var seconds: Int?
        public init() {}
    }

    public static let wordsPerMinute = 230

    public static func parse(_ html: String, url: String) -> Meta {
        var m = Meta()
        let tags = metaTags(in: html)
        func tag(_ names: String...) -> String? {
            for n in names { if let v = tags[n], !v.isEmpty { return YouTube.decodeEntities(v) } }
            return nil
        }

        m.title = tag("og:title", "twitter:title")
            ?? html.firstMatch(of: #"(?is)<title[^>]*>(.*?)</title>"#).map {
                YouTube.decodeEntities($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        m.site = tag("og:site_name", "application-name") ?? host(of: url)
        m.imageURL = tag("og:image", "og:image:url", "twitter:image").flatMap { absolute($0, base: url) }
        m.blurb = tag("og:description", "description", "twitter:description")
        m.kind = kind(url: url, ogType: tags["og:type"], html: html)

        switch m.kind {
        case .podcast, .video:
            if let iso = html.firstMatch(of: #""duration"\s*:\s*"(P[T0-9HMS.]+)""#) {
                m.seconds = YouTube.isoToSeconds(iso.replacingOccurrences(of: #"\.\d+"#, with: "",
                                                                         options: .regularExpression))
            }
            if m.seconds == nil, let s = tag("og:video:duration", "music:duration", "og:audio:duration") {
                m.seconds = Int(s)
            }
        case .article, .page:
            // An article promises a reading time even when short; a page only
            // when it clearly is text, not a menu with a few links.
            let words = wordCount(html)
            if words >= (m.kind == .article ? 40 : 150) {
                let minutes = max(1, Int((Double(words) / Double(wordsPerMinute)).rounded()))
                m.seconds = minutes * 60
            }
        }
        return m
    }

    /// Every `<meta>` tag as name → content, whichever of `property`/`name`
    /// carries the name and whichever order the attributes come in.
    static func metaTags(in html: String) -> [String: String] {
        let tagRe = try! NSRegularExpression(pattern: #"(?is)<meta\s[^>]*>"#)
        let attrRe = try! NSRegularExpression(pattern: #"(?is)([a-z:_-]+)\s*=\s*("([^"]*)"|'([^']*)')"#)
        let ns = html as NSString
        var out: [String: String] = [:]
        for t in tagRe.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: t.range)
            let tns = tag as NSString
            var attrs: [String: String] = [:]
            for a in attrRe.matches(in: tag, range: NSRange(location: 0, length: tns.length)) {
                let key = tns.substring(with: a.range(at: 1)).lowercased()
                let v = a.range(at: 3).location != NSNotFound ? tns.substring(with: a.range(at: 3))
                                                              : tns.substring(with: a.range(at: 4))
                attrs[key] = v
            }
            if let name = (attrs["property"] ?? attrs["name"] ?? attrs["itemprop"])?.lowercased(),
               let content = attrs["content"], out[name] == nil {
                out[name] = content
            }
        }
        return out
    }

    static func kind(url: String, ogType: String?, html: String) -> ItemKind {
        let u = url.lowercased()
        let podcastHosts = ["podcasts.apple.com", "open.spotify.com/episode", "overcast.fm", "pca.st",
                            "pocketcasts.com", "castro.fm", "podcasts.google.com"]
        if podcastHosts.contains(where: { u.contains($0) }) { return .podcast }
        let t = (ogType ?? "").lowercased()
        if t.contains("podcast") || t.hasPrefix("music") { return .podcast }
        if t.hasPrefix("video") || u.contains("vimeo.com/") { return .video }
        if t == "article" || t.hasPrefix("article") { return .article }
        if html.range(of: "<article", options: .caseInsensitive) != nil { return .article }
        return .page
    }

    /// Words of running text: inside `<article>` when there is one (so menus and
    /// footers do not count), otherwise the whole body; scripts and styles out.
    static func wordCount(_ html: String) -> Int {
        var text = html
        if let inner = html.firstMatch(of: #"(?is)<article[^>]*>(.*)</article>"#) { text = inner }
        for p in [#"(?is)<script.*?</script>"#, #"(?is)<style.*?</style>"#, #"(?is)<nav.*?</nav>"#,
                  #"(?is)<footer.*?</footer>"#, #"(?s)<[^>]+>"#] {
            text = text.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        return text.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: \.isLetter) }.count
    }

    public static func host(of url: String) -> String? {
        guard var h = URL(string: url)?.host else { return nil }
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }

    static func absolute(_ ref: String, base: String) -> String? {
        if ref.hasPrefix("http") { return ref }
        if ref.hasPrefix("//") { return "https:" + ref }
        return URL(string: ref, relativeTo: URL(string: base))?.absoluteString
    }
}

public extension Clock {
    /// What he types for a moment: "12:34", "1:02:03", or plain "12" meaning
    /// twelve minutes — nobody means twelve seconds when they type 12.
    static func parseMoment(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if t.contains(":") { return YouTube.clockToSeconds(t) }
        guard let minutes = Double(t.replacingOccurrences(of: ",", with: ".")), minutes >= 0 else { return nil }
        return Int((minutes * 60).rounded())
    }
}
