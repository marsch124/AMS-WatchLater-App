import Foundation

/// The one file, and the only way to touch it. Used by the app AND by the
/// share extension, so a video shared from the phone lands in the same file
/// the Mac reads — merged, never overwritten.
public struct LibraryFile {
    public let url: URL
    private let coordinator = NSFileCoordinator()

    public init(url: URL) { self.url = url }

    public func read() -> Library {
        var out = Library()
        var err: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &err) { u in
            if let raw = try? Data(contentsOf: u),
               let lib = try? JSONDecoder.watchLater.decode(Library.self, from: raw) {
                out = lib
            }
        }
        return out
    }

    /// Merges against whatever is on disk first, so the other device's work
    /// is never flattened by this one's copy. Returns what was written.
    @discardableResult
    public func write(_ library: Library, version: String) -> Library {
        var toWrite = library
        toWrite.version = version
        toWrite.savedAt = Date()
        var err: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &err) { u in
            if let raw = try? Data(contentsOf: u),
               let onDisk = try? JSONDecoder.watchLater.decode(Library.self, from: raw) {
                toWrite = Library.merged(onDisk, toWrite)
                toWrite.version = version
            }
            toWrite.purgeTombstones()
            if let payload = try? JSONEncoder.watchLater.encode(toWrite) {
                try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                try? payload.write(to: u, options: .atomic)
            }
        }
        return toWrite
    }

    /// Adds a link with only what is known — the title can be the address
    /// itself; the app fills in the rest the next time it looks. A video already
    /// on the list is left alone; one that was binned comes back.
    @discardableResult
    public func addBare(url raw: String, version: String) -> Library {
        var lib = read()
        let link = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = YouTube.videoId(in: link)
        let now = Date()
        if let i = lib.items.firstIndex(where: { id != nil ? $0.videoId == id : $0.url == link }) {
            if lib.items[i].deletedAt != nil {
                lib.items[i].deletedAt = nil
                lib.items[i].savedAt = now
                lib.items[i].modifiedAt = now
            }
        } else {
            let v = Video(videoId: id, url: id.map(YouTube.watchURL) ?? link, title: "",
                          savedAt: now, isShort: YouTube.isShortLink(link))
            lib.items.insert(v, at: 0)
        }
        return write(lib, version: version)
    }
}
