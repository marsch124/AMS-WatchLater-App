import Foundation
import SwiftUI
import WatchLaterCore

/// Everything the app knows, and the only thing allowed to touch the file.
@MainActor
final class Store: ObservableObject {

    @Published private(set) var library = Library()
    @Published var toast: Toast?
    @Published var busy: String?
    @Published private(set) var syncPlace = "This device"
    @Published private(set) var thumbTick = 0     // bumped when a picture lands

    let isTestRun: Bool
    /// No network in a test run: cards keep what the seed gave them.
    let offline: Bool
    private let file: LibraryFile
    let root: URL
    private var query: NSMetadataQuery?
    private var toastWork: Task<Void, Never>?

    static let appGroup = "group.com.schabbauer.AMSWatchLater"
    static let container = "iCloud.com.schabbauer.AMSWatchLater"

    /// YES only in a build carrying the iCloud entitlements (see project.yml).
    static var usesICloud: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "WatchLaterUsesICloud") as? String) == "YES"
    }

    // MARK: Where the file lives

    init(root: URL? = nil) {
        let args = ProcessInfo.processInfo.arguments
        isTestRun = args.contains("-uiTesting")
        offline = isTestRun
        let home = root ?? Store.defaultRoot(freshForTests: isTestRun)
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        self.root = home
        file = LibraryFile(url: home.appendingPathComponent("watchlater.json"))
        syncPlace = home.path.contains("Mobile Documents") ? "iCloud Drive" : "This device"
        if isTestRun, args.contains("-seed") {
            file.write(Store.seed(), version: Guide.appVersion)
        }
        reload()
        adoptLocalListIfCloudIsEmpty()
        backUpDaily()
        watchForChanges()
    }

    /// Build 6 kept the list on the device (it shipped without the iCloud
    /// entitlement). The first build that CAN see iCloud finds that list here
    /// and carries it over, so nothing he imported has to be imported twice.
    private func adoptLocalListIfCloudIsEmpty() {
        guard !isTestRun, syncPlace == "iCloud Drive", library.live.isEmpty else { return }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AMSWatchLater", isDirectory: true)
        let local = LibraryFile(url: support.appendingPathComponent("watchlater.json")).read()
        guard !local.live.isEmpty else { return }
        library = file.write(local, version: Guide.appVersion)
        say("Moved \(local.live.count) videos into iCloud")
    }

    private static func defaultRoot(freshForTests: Bool) -> URL {
        let fm = FileManager.default
        if freshForTests {
            return fm.temporaryDirectory.appendingPathComponent("AMSWatchLater-UITest-\(UUID().uuidString)")
        }
        // One file in iCloud Drive means the phone and the Mac are literally
        // reading the same list. No cloud? The list stays on this device.
        if usesICloud, let cloud = fm.url(forUbiquityContainerIdentifier: container) {
            return cloud.appendingPathComponent("Documents", isDirectory: true)
        }
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AMSWatchLater", isDirectory: true)
    }

    /// Three videos of known lengths, so a UI test can prove the time slots.
    static func seed() -> Library {
        func v(_ id: String, _ title: String, _ channel: String, _ seconds: Int, daysAgo: Double) -> Video {
            var x = Video(videoId: id, url: YouTube.watchURL(for: id), title: title, channel: channel,
                          seconds: seconds, savedAt: Date().addingTimeInterval(-daysAgo * 86_400))
            x.id = "seed-\(id)"
            return x
        }
        return Library(items: [
            v("seedfour000", "Four minutes on knots", "Rope Club", 4 * 60, daysAgo: 0),
            v("seedfifteen", "Fifteen minutes of Raycast", "Raycast", 15 * 60, daysAgo: 1),
            v("seedfifty00", "Fifty minutes of brain science", "Anders Hansen", 50 * 60, daysAgo: 100),
        ])
    }

    // MARK: Load & save

    func reload() {
        library = file.read()
        drainInbox()
        Task { await resolveBare(); await fetchThumbs() }
    }

    /// Applies a change and writes it — merged against the file first, so the
    /// other device's work is never flattened by this one's copy.
    private func commit(_ change: (inout Library) -> Void) {
        var lib = library
        change(&lib)
        library = file.write(lib, version: Guide.appVersion)
    }

    private func stamp(_ id: String, _ change: (inout Video) -> Void) {
        commit { lib in
            guard let i = lib.items.firstIndex(where: { $0.id == id }) else { return }
            change(&lib.items[i])
            lib.items[i].modifiedAt = Date()
        }
    }

    /// One dated copy a day, beside the file — and a copy is never replaced by
    /// a smaller one, so a list that was emptied by mistake still has yesterday.
    private func backUpDaily() {
        guard !isTestRun, !library.live.isEmpty else { return }
        let folder = root.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let day = ISO8601DateFormatter.day.string(from: Date())
        let target = folder.appendingPathComponent("watchlater-\(day).json")
        if let raw = try? Data(contentsOf: target),
           let old = try? JSONDecoder.watchLater.decode(Library.self, from: raw),
           old.live.count > library.live.count { return }
        if let payload = try? JSONEncoder.watchLater.encode(library) {
            try? payload.write(to: target, options: .atomic)
        }
    }

    func backups() -> [URL] {
        let folder = root.appendingPathComponent("Backups", isDirectory: true)
        let list = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return list.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    // MARK: Hearing the other device

    private func watchForChanges() {
        guard !isTestRun, syncPlace == "iCloud Drive" else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "watchlater.json")
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: q, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cloudFileChanged() }
        }
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cloudFileChanged() }
        }
        q.start()
        query = q
    }

    private func cloudFileChanged() {
        // A file another device wrote may only be a placeholder here yet.
        try? FileManager.default.startDownloadingUbiquitousItem(at: file.url)
        let fresh = file.read()
        if fresh != library {
            library = fresh
            Task { await resolveBare(); await fetchThumbs() }
        }
    }

    // MARK: Adding

    struct Added {
        var added = 0, duplicates = 0, refused = 0, fromPlaylist = false
        var line: String {
            if added == 0 && duplicates > 0 && refused == 0 { return duplicates == 1 ? "Already on the list" : "All already on the list" }
            if added == 0 && refused > 0 { return "Could not read that link" }
            var s = added == 1 ? "Added" : "Added \(added)"
            if fromPlaylist { s += " from a playlist" }
            if duplicates > 0 { s += " · \(duplicates) already here" }
            if refused > 0 { s += " · \(refused) unreadable" }
            return s
        }
    }

    /// The paste box, the share sheet, Safari and Raycast all come through
    /// here, so a playlist behaves the same at every door.
    func add(text: String) async -> Added {
        var result = Added()
        var links = YouTube.links(in: text)
        if links.isEmpty {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { links = [t.hasPrefix("http") ? t : "https://" + t] }
        }
        busy = links.count > 1 ? "Adding \(links.count) links…" : "Adding…"
        defer { busy = nil }
        for link in links {
            if YouTube.isBarePlaylist(link), let list = YouTube.playlistId(in: link) {
                let rows = await YouTubeClient.shared.playlist(list)
                result.fromPlaylist = !rows.isEmpty
                // Added last-first, so the playlist's own first video ends up on top.
                for row in rows.reversed() {
                    await addOne(YouTube.watchURL(for: row.id), hint: row.seconds, into: &result)
                }
                if rows.isEmpty { result.refused += 1 }
            } else {
                await addOne(link, hint: nil, into: &result)
            }
        }
        return result
    }

    private func addOne(_ link: String, hint: Int?, into result: inout Added) async {
        let id = YouTube.videoId(in: link)
        if let existing = library.items.first(where: { id != nil ? $0.videoId == id : $0.url == link }) {
            if existing.deletedAt != nil {
                stamp(existing.id) { $0.deletedAt = nil; $0.savedAt = Date() }
                result.added += 1
            } else {
                result.duplicates += 1
            }
            return
        }
        var v = Video(videoId: id, url: id.map(YouTube.watchURL) ?? link, title: "",
                      isShort: YouTube.isShortLink(link))
        if let id, !offline {
            let m = await YouTubeClient.shared.meta(for: id, hintSeconds: hint)
            // Every lookup failed: dead, private or mistyped. Refuse it rather
            // than park a blank card that has no picture, no length and no name.
            guard let title = m.title else { result.refused += 1; return }
            v.title = title
            v.channel = m.channel ?? ""
            v.seconds = m.seconds
        } else {
            v.title = link
        }
        commit { $0.items.insert(v, at: 0) }
        result.added += 1
        if let id { Task { await Thumbs.fetchIfMissing(id); thumbTick += 1 } }
    }

    /// Cards the share extension saved with only a link get their words now.
    func resolveBare() async {
        guard !offline else { return }
        for v in library.items where v.title.isEmpty && v.deletedAt == nil {
            guard let id = v.videoId else { stamp(v.id) { $0.title = $0.url }; continue }
            let m = await YouTubeClient.shared.meta(for: id)
            stamp(v.id) {
                $0.title = m.title ?? $0.url
                $0.channel = m.channel ?? ""
                $0.seconds = m.seconds ?? $0.seconds
                if m.title == nil { $0.goneAt = Date() }
            }
        }
    }

    func fetchThumbs() async {
        guard !offline else { return }
        for id in library.live.compactMap(\.videoId) where !Thumbs.have(id) {
            await Thumbs.fetchIfMissing(id)
            thumbTick += 1
        }
    }

    /// Re-reads one video from YouTube; one that has been taken down is
    /// flagged, never deleted.
    func check(_ v: Video) async {
        guard let id = v.videoId, !offline else { return }
        let m = await YouTubeClient.shared.meta(for: id)
        stamp(v.id) {
            $0.checkedAt = Date()
            if let t = m.title { $0.title = t; $0.goneAt = nil } else { $0.goneAt = Date() }
            if let c = m.channel { $0.channel = c }
            if let s = m.seconds { $0.seconds = s }
        }
        say(m.title == nil ? "That video seems to be gone" : "Checked — still there")
    }

    // MARK: The share extension's inbox

    /// Without iCloud the extension cannot reach the file, so it leaves links
    /// in the app group; they are taken in here the next time the app looks.
    func drainInbox() {
        guard let inbox = Store.inboxURL, let raw = try? String(contentsOf: inbox, encoding: .utf8) else { return }
        let links = raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        try? FileManager.default.removeItem(at: inbox)
        guard !links.isEmpty else { return }
        Task {
            let r = await add(text: links.joined(separator: "\n"))
            say(r.line)
        }
    }

    static var inboxURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("inbox.txt")
    }

    // MARK: What he does to a card

    func setWatched(_ v: Video, _ on: Bool) {
        stamp(v.id) { $0.watchedAt = on ? Date() : nil; if on { $0.answeredAt = Date() } }
        if on { say("Watched", undo: { [weak self] in self?.setWatched(v, false) }) }
    }

    func keep(_ v: Video) { stamp(v.id) { $0.keptAt = Date() }; say("Kept") }

    func togglePin(_ v: Video) { stamp(v.id) { $0.pinnedAt = $0.pinnedAt == nil ? Date() : nil } }

    func toggleTogether(_ v: Video) { stamp(v.id) { $0.togetherAt = $0.togetherAt == nil ? Date() : nil } }

    /// The bin does not delete: it stamps, and Undo unstamps.
    func bin(_ v: Video) {
        stamp(v.id) { $0.deletedAt = Date() }
        say("Removed", undo: { [weak self] in self?.restore(v) })
    }

    func bin(_ vs: [Video]) {
        commit { lib in
            for v in vs { if let i = lib.items.firstIndex(where: { $0.id == v.id }) {
                lib.items[i].deletedAt = Date(); lib.items[i].modifiedAt = Date() } }
        }
        say("Removed \(vs.count)", undo: { [weak self] in vs.forEach { self?.restore($0) } })
    }

    func restore(_ v: Video) { stamp(v.id) { $0.deletedAt = nil } }

    func setNote(_ v: Video, _ note: String) { stamp(v.id) { $0.note = note.trimmingCharacters(in: .whitespacesAndNewlines) } }

    func setTags(_ v: Video, _ tags: [String]) { stamp(v.id) { $0.tags = YouTube.cleanTags(tags) } }

    func setSeconds(_ v: Video, _ seconds: Int?) { stamp(v.id) { $0.seconds = seconds } }

    /// He opened it. The card asks about it when he comes back.
    func started(_ v: Video) {
        guard v.isOpen else { return }
        stamp(v.id) { $0.startedAt = Date(); $0.answeredAt = nil }
    }

    func answer(_ v: Video, finished: Bool) {
        if finished { setWatched(v, true) } else { stamp(v.id) { $0.answeredAt = Date() } }
    }

    // MARK: Import & export

    /// The old app's watchlater.json — every card, kept as it was. A card
    /// already here is left alone.
    func importOld(_ data: Data) -> Int {
        guard let old = try? JSONDecoder.watchLater.decode(Library.self, from: data) else { return -1 }
        var n = 0
        commit { lib in
            for v in old.items where v.deletedAt == nil {
                if lib.items.contains(where: { $0.id == v.id || ($0.videoId != nil && $0.videoId == v.videoId) }) { continue }
                lib.items.append(v)
                n += 1
            }
            lib.items.sort { $0.savedAt > $1.savedAt }
        }
        Task { await fetchThumbs() }
        return n
    }

    func exportData() -> Data {
        (try? JSONEncoder.watchLater.encode(library)) ?? Data()
    }

    // MARK: Saying things

    func say(_ text: String, undo: (() -> Void)? = nil) {
        toast = Toast(text: text, undo: undo)
        toastWork?.cancel()
        toastWork = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
