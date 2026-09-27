import Foundation
import WatchLaterCore

/// The network side of YouTube. A native app has no CORS wall, so this does
/// what the old Node engine existed to do: read the watch page for the length.
/// All parsing is in the Core package; this only fetches.
actor YouTubeClient {
    static let shared = YouTubeClient()

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept-Language": "en",
        ]
        return URLSession(configuration: c)
    }()

    private func get(_ url: String) async throws -> Data {
        guard let u = URL(string: url) else { throw URLError(.badURL) }
        let (data, resp) = try await session.data(from: u)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Title and channel from oEmbed, length from the watch page. A length that
    /// came off a playlist page spares the heavy watch-page fetch.
    func meta(for id: String, hintSeconds: Int? = nil) async -> YouTube.Meta {
        var m = YouTube.Meta()
        let watch = YouTube.watchURL(for: id)
        if let data = try? await get("https://www.youtube.com/oembed?url=\(watch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? watch)&format=json") {
            m = YouTube.parseOEmbed(data)
        }
        if let s = hintSeconds {
            m.seconds = s
            if m.title != nil { return m }
        }
        if let data = try? await get(watch), let html = String(data: data, encoding: .utf8) {
            let page = YouTube.parseWatchPage(html)
            if m.seconds == nil { m.seconds = page.seconds }
            if m.title == nil { m.title = page.title }
            if m.channel == nil { m.channel = page.channel }
        }
        return m
    }

    func playlist(_ listId: String) async -> [YouTube.PlaylistRow] {
        guard let data = try? await get("https://www.youtube.com/playlist?list=\(listId)"),
              let html = String(data: data, encoding: .utf8) else { return [] }
        return YouTube.parsePlaylistPage(html)
    }

    /// Any other link: its own meta tags say what it is.
    func page(_ url: String) async -> Page.Meta? {
        guard let data = try? await get(url) else { return nil }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return Page.parse(html, url: url)
    }

    func image(_ url: URL) async -> Data? {
        try? await get(url.absoluteString)
    }
}

/// Pictures live per device, in Caches — they come back from YouTube in a
/// moment and never need to travel through iCloud.
enum Thumbs {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let f = base.appendingPathComponent("Thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: f, withIntermediateDirectories: true)
        return f
    }()

    static func url(for key: String) -> URL { folder.appendingPathComponent("\(key).jpg") }

    static func have(_ key: String) -> Bool { FileManager.default.fileExists(atPath: url(for: key).path) }

    /// A card's picture: YouTube's for a video, the page's own for anything else.
    static func fetchIfMissing(_ item: Video) async {
        let key = item.thumbKey
        guard !have(key), let remote = item.thumbnailURL,
              let data = await YouTubeClient.shared.image(remote), data.count > 500 else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }
}
