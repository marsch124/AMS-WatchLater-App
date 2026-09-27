import XCTest
@testable import WatchLaterCore

final class LibraryTests: XCTestCase {

    private func video(_ id: String, seconds: Int?, daysAgo: Double = 0, short: Bool = false) -> Video {
        var v = Video(id: id, videoId: id.padding(toLength: 11, withPad: "x", startingAt: 0),
                      url: "https://www.youtube.com/watch?v=\(id)", title: "Video \(id)",
                      channel: "Channel \(id.prefix(1))", seconds: seconds,
                      savedAt: Date().addingTimeInterval(-daysAgo * 86_400), isShort: short)
        v.modifiedAt = v.savedAt
        return v
    }

    // MARK: The web app's file reads straight in

    func testTheOldFileReadsStraightIn() throws {
        let json = """
        {"version":"1.16","items":[{"id":"muiqnt6pn4422","videoId":"m5MDv9qwhU8",
        "url":"https://www.youtube.com/watch?v=m5MDv9qwhU8","title":"Max Stoiber Owns His Workflow with Raycast",
        "channel":"Raycast","seconds":915,"savedAt":"2026-09-26T18:44:12.289Z","watchedAt":null,"keptAt":null,
        "isShort":false,"pinnedAt":null,"togetherAt":null,"deletedAt":null,"startedAt":null,"answeredAt":null,
        "checkedAt":null,"goneAt":null,"tags":[],"note":""},
        {"id":"old","videoId":"aaaaaaaaaaa","url":"u","title":"Old","savedAt":"2026-08-01T10:00:00Z"}]}
        """
        let lib = try JSONDecoder.watchLater.decode(Library.self, from: Data(json.utf8))
        XCTAssertEqual(lib.version, "1.16")
        XCTAssertEqual(lib.items.count, 2)
        XCTAssertEqual(lib.items[0].seconds, 915)
        XCTAssertEqual(lib.items[0].modifiedAt, lib.items[0].savedAt, "an old card is as old as its save")
        XCTAssertEqual(lib.items[1].tags, [])
        XCTAssertEqual(lib.items[1].channel, "")

        // And what we write, we can read.
        let again = try JSONDecoder.watchLater.decode(Library.self, from: JSONEncoder.watchLater.encode(lib))
        XCTAssertEqual(again.items.map(\.id), lib.items.map(\.id))
        XCTAssertEqual(again.items[0].savedAt.timeIntervalSince1970,
                       lib.items[0].savedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: Merging two devices

    func testMergeTakesTheLaterChangeAndKeepsBothSidesCards() {
        let a = video("a", seconds: 100), b = video("b", seconds: 200)
        var mine = Library(items: [a, b])
        var theirs = Library(items: [a, b])
        mine.items[0].note = "mine"; mine.items[0].modifiedAt = Date().addingTimeInterval(10)
        theirs.items[0].note = "theirs"; theirs.items[0].modifiedAt = Date()
        theirs.items[1].deletedAt = Date(); theirs.items[1].modifiedAt = Date().addingTimeInterval(5)
        theirs.items.append(video("c", seconds: 300))

        let m = Library.merged(mine, theirs)
        XCTAssertEqual(m.items.count, 3)
        XCTAssertEqual(m.items.first { $0.id == "a" }?.note, "mine")
        XCTAssertNotNil(m.items.first { $0.id == "b" }?.deletedAt, "a bin on one device is a change, not a loss")
        XCTAssertEqual(m.live.map(\.id).sorted(), ["a", "c"])
    }

    func testTombstonesOutliveAMonthThenGo() {
        var lib = Library(items: [video("a", seconds: 1), video("b", seconds: 1)])
        lib.items[0].deletedAt = Date().addingTimeInterval(-31 * 86_400)
        lib.items[1].deletedAt = Date().addingTimeInterval(-2 * 86_400)
        lib.purgeTombstones()
        XCTAssertEqual(lib.items.map(\.id), ["b"])
    }

    // MARK: The file

    func testFileWriteMergesWithWhatIsOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = LibraryFile(url: dir.appendingPathComponent("watchlater.json"))
        XCTAssertEqual(file.read().items.count, 0, "no file yet reads as empty")

        file.write(Library(items: [video("a", seconds: 100)]), version: "0.1")
        // Another device wrote a second card meanwhile — simulate by writing a
        // library that does not know about "a".
        let written = file.write(Library(items: [video("b", seconds: 200)]), version: "0.1")
        XCTAssertEqual(written.live.map(\.id).sorted(), ["a", "b"])
        XCTAssertEqual(file.read().live.count, 2)
        XCTAssertEqual(file.read().version, "0.1")
    }

    func testAddBareRevivesABinnedVideoAndIgnoresADuplicate() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = LibraryFile(url: dir.appendingPathComponent("watchlater.json"))
        var lib = Library(items: [video("a", seconds: 100)])
        lib.items[0].videoId = "aaaaaaaaaaa"
        lib.items[0].deletedAt = Date()
        file.write(lib, version: "0.1")

        let revived = file.addBare(url: "https://youtu.be/aaaaaaaaaaa", version: "0.1")
        XCTAssertEqual(revived.live.count, 1)
        XCTAssertNil(revived.items[0].deletedAt)

        let same = file.addBare(url: "https://www.youtube.com/watch?v=aaaaaaaaaaa&t=3", version: "0.1")
        XCTAssertEqual(same.items.count, 1, "the same video with a timestamp is not a new card")

        let fresh = file.addBare(url: "https://youtube.com/shorts/bbbbbbbbbbb", version: "0.1")
        XCTAssertEqual(fresh.live.count, 2)
        let s = fresh.items.first { $0.videoId == "bbbbbbbbbbb" }!
        XCTAssertTrue(s.isShort)
        XCTAssertEqual(s.title, "", "a bare card has no title until the app looks it up")
        XCTAssertEqual(s.url, "https://www.youtube.com/watch?v=bbbbbbbbbbb")
    }

    // MARK: The shelf

    func testBucketsKeepShortsOutOfTheTimedSlots() {
        let lib = Library(items: [
            video("a", seconds: 240), video("b", seconds: 15 * 60), video("c", seconds: 50 * 60),
            video("d", seconds: 11, short: true), video("e", seconds: nil),
        ])
        let counts = Shelf.counts(lib)
        XCTAssertEqual(counts[.five], 1)
        XCTAssertEqual(counts[.twenty], 2)
        XCTAssertEqual(counts[.hour], 3)
        XCTAssertEqual(counts[.everything], 5)
        XCTAssertEqual(Shelf.shortsCount(lib), 1)

        var shelf = Shelf()
        shelf.bucket = .five
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a"])
        shelf.shortsOnly = true
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["d"])
    }

    func testSearchIsAccentBlindAndPinnedComesFirst() {
        var lib = Library(items: [video("a", seconds: 100, daysAgo: 1), video("b", seconds: 100, daysAgo: 0)])
        lib.items[0].title = "Hjärnans hemligheter"
        lib.items[0].pinnedAt = Date()
        var shelf = Shelf()
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a", "b"], "pinned first even though older")
        shelf.search = "hjarnans"
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a"])
    }

    func testWatchedAndStale() {
        var lib = Library(items: [video("a", seconds: 100, daysAgo: 100), video("b", seconds: 100, daysAgo: 1)])
        lib.items[1].watchedAt = Date()
        XCTAssertTrue(lib.items[0].isStale())
        var shelf = Shelf()
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a"])
        shelf.showWatched = true
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["b"])
    }

    // MARK: Words

    func testClockWords() {
        XCTAssertEqual(Clock.badge(250), "4:10")
        XCTAssertEqual(Clock.badge(3723), "1:02:03")
        XCTAssertNil(Clock.badge(nil))
        XCTAssertEqual(Clock.total([video("a", seconds: 3600), video("b", seconds: 23 * 60)]), "1 h 23 min")
        XCTAssertEqual(Clock.total([video("a", seconds: 120), video("b", seconds: nil)]), "2 min+")
        XCTAssertEqual(Clock.relative(Date()), "today")
        XCTAssertEqual(Clock.relative(Date().addingTimeInterval(-3 * 86_400)), "3 days ago")
        XCTAssertEqual(Clock.relative(Date().addingTimeInterval(-40 * 86_400)), "last month")
    }

    // MARK: Planning an evening

    func testPlanFillsTheBudgetExactlyWhenItCan() {
        let pool = [video("a", seconds: 44 * 60), video("b", seconds: 16 * 60), video("c", seconds: 8 * 60),
                    video("d", seconds: 61), video("e", seconds: 7 * 60), video("s", seconds: 20, short: true)]
        for _ in 0..<5 {
            let plan = Planner.plan(minutes: 45, from: pool)
            XCTAssertEqual(plan.compactMap(Planner.minutes).reduce(0, +), 45)
            XCTAssertFalse(plan.contains { $0.countsAsShort }, "a Short is not an evening")
        }
        XCTAssertEqual(Planner.plan(minutes: 10, from: pool, shuffle: false).map(\.id), ["c", "d"])
        XCTAssertEqual(Planner.plan(minutes: 0, from: pool), [])
    }

    func testTogetherMessage() {
        let vs = [video("a", seconds: 250), video("b", seconds: nil)]
        let msg = Together.message(for: vs)
        XCTAssertTrue(msg.hasPrefix("Shall we watch these?\n\n1. Video a (4:10)\n2. Video b\n\n"))
        XCTAssertTrue(msg.hasSuffix("watch_videos?video_ids=axxxxxxxxxx,bxxxxxxxxxx"))
        XCTAssertNil(Together.link(for: []))
    }
}
