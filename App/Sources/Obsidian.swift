import Foundation
import WatchLaterCore

/// Writes the notes into the Obsidian vault he chose — on this device; each
/// device remembers its own choice (the vault lives in a different place on
/// the Mac and the iPhone).
///
/// A small manifest in the export folder remembers what the app wrote, so a
/// note he has changed in Obsidian is never overwritten, and nothing is ever
/// deleted.
@MainActor
enum ObsidianShelf {
    private static let key = "obsidianFolderBookmark"
    private static let nameKey = "obsidianFolderName"
    static let manifestName = ".watchlater-export.json"

    struct Report: Equatable {
        var written = 0
        var unchanged = 0
        var keptHis: [String] = []
        var line: String {
            var parts: [String] = []
            parts.append(written == 0 ? "Nothing new to write" : "\(written) note\(written == 1 ? "" : "s") written")
            if !keptHis.isEmpty {
                parts.append("\(keptHis.count) you changed in Obsidian left as they are")
            }
            return parts.joined(separator: " · ")
        }
    }

    struct Trouble: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Set by UI test runs: a throwaway vault, never his.
    static var testVault: URL?

    /// The vault's name, or nil before one is chosen.
    static var folderName: String? { testVault != nil ? "Test vault" : UserDefaults.standard.string(forKey: nameKey) }

    #if os(macOS)
    private static let makeOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let readOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
    private static let makeOptions: URL.BookmarkCreationOptions = []
    private static let readOptions: URL.BookmarkResolutionOptions = []
    #endif

    /// Remembers the folder he picked (from the file picker).
    static func choose(_ url: URL) throws {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: makeOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
    }

    private static func vault() throws -> URL {
        if let testVault {
            try FileManager.default.createDirectory(at: testVault, withIntermediateDirectories: true)
            return testVault
        }
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw Trouble(message: "Choose your Obsidian vault first.")
        }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: readOptions, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            throw Trouble(message: "The vault could not be found any more. Choose it again.")
        }
        if stale, let fresh = try? url.bookmarkData(options: makeOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: key)
        }
        return url
    }

    /// Everything, or one card (then its topics and the index are refreshed too).
    static func export(_ library: Library, only card: Video? = nil) throws -> Report {
        let root = try vault()
        let ok = root.startAccessingSecurityScopedResource()
        defer { if ok { root.stopAccessingSecurityScopedResource() } }
        let folder = root.appendingPathComponent(ObsidianExport.folder, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let manifestURL = folder.appendingPathComponent(manifestName)
        var manifest = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: manifestURL))) ?? [:]

        var notes = ObsidianExport.all(library)
        if let card {
            let own = ObsidianExport.names(library)[card.id].map { "\($0).md" }
            let topics = Set(card.tags.map { "Topics/\(ObsidianExport.fileName($0)).md" })
            notes = notes.filter { $0.path == own || topics.contains($0.path) || $0.path == "WatchLater.md" }
        }

        var report = Report()
        let coordinator = NSFileCoordinator()
        for n in notes {
            let url = folder.appendingPathComponent(n.path)
            let onDisk = try? String(contentsOf: url, encoding: .utf8)
            switch ObsidianExport.plan(n, onDisk: onDisk, manifest: manifest) {
            case .same:
                report.unchanged += 1
                manifest[n.path] = ObsidianExport.fingerprint(n.text)
            case .keepHis:
                report.keptHis.append(n.path)
            case .write:
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                var failure: Error?
                var coordError: NSError?
                coordinator.coordinate(writingItemAt: url, options: [], error: &coordError) { u in
                    do { try Data(n.text.utf8).write(to: u, options: .atomic) } catch { failure = error }
                }
                if let e = failure ?? coordError { throw e }
                manifest[n.path] = ObsidianExport.fingerprint(n.text)
                report.written += 1
            }
        }
        if let data = try? JSONEncoder().encode(manifest) { try? data.write(to: manifestURL, options: .atomic) }
        return report
    }
}
