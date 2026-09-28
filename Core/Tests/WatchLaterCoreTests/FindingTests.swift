import XCTest
@testable import WatchLaterCore

/// Step 2 — Finding: what was said, saved searches, filters.
final class FindingTests: XCTestCase {

    /// A cut-down copy of the real caption file YouTube's player downloaded for
    /// m5MDv9qwhU8 on 2026-09-28: word pieces, and aAppend line breaks.
    let json3 = """
    {"wireMagic":"pb3","events":[
      {"tStartMs":0,"dDurationMs":916040,"id":1},
      {"tStartMs":399,"dDurationMs":5601,"wWinId":1,"segs":[{"utf8":"I"},{"utf8":" hate","tOffsetMs":241},{"utf8":" friction","tOffsetMs":841}]},
      {"tStartMs":3669,"dDurationMs":2331,"wWinId":1,"aAppend":1,"segs":[{"utf8":"\\n"}]},
      {"tStartMs":3679,"dDurationMs":4401,"wWinId":1,"segs":[{"utf8":"in"},{"utf8":" many"},{"utf8":" different"},{"utf8":" ways"}]},
      {"tStartMs":95000,"dDurationMs":3000,"wWinId":1,"segs":[{"utf8":"the hyper key is caps lock &amp; more"}]},
      {"tStartMs":412000,"dDurationMs":3000,"wWinId":1,"segs":[{"utf8":"snippets"},{"utf8":" with the hyper key"}]},
      {"tStartMs":500000,"dDurationMs":1000,"wWinId":1,"segs":[{"utf8":"  "}]}
    ]}
    """

    func testTheCaptionFileBecomesTimedLines() {
        let lines = Transcript.parseJSON3(Data(json3.utf8))
        XCTAssertEqual(lines.map(\.s), ["I hate friction", "in many different ways",
                                        "the hyper key is caps lock & more", "snippets with the hyper key"])
        XCTAssertEqual(lines.map(\.seconds), [0, 3, 95, 412])
        XCTAssertEqual(Transcript.parseJSON3(Data("not json".utf8)), [])
    }

    func testTheOlderXMLCaptionsReadTheSame() {
        let xml = #"<?xml version="1.0"?><timedtext format="3"><body><p t="1200" d="900"><s>Hello</s><s t="300"> there</s></p><p t="95000" d="1000">caps &amp; lock</p><p t="99000" d="10"> </p></body></timedtext>"#
        let lines = Transcript.parse(Data(xml.utf8))
        XCTAssertEqual(lines.map(\.s), ["Hello there", "caps & lock"])
        XCTAssertEqual(lines.map(\.seconds), [1, 95])
        XCTAssertEqual(Transcript.parse(Data(json3.utf8)).count, 4, "and JSON still goes to the JSON reader")
    }

    func testFindSaysWhenItWasSaidAndHowOften() {
        let v = Video(id: "a", videoId: "aaaaaaaaaaa", url: "u", title: "Max Stoiber on Raycast")
        let t = Transcript(videoId: "aaaaaaaaaaa", lines: Transcript.parseJSON3(Data(json3.utf8)))
        let hits = Finder.search(Library(items: [v]), "hyper key", transcripts: ["aaaaaaaaaaa": t])
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].place, .said(seconds: 95))
        XCTAssertEqual(hits[0].alsoSaid, 1, "said twice: the first moment, and one more")
        XCTAssertTrue(hits[0].snippet.contains("hyper key"), hits[0].snippet)
        // The words sit near the start of a spoken snippet, not 40 letters in,
        // so a two-line row on the phone still shows them.
        let late = Finder.search(Library(items: [v]), "snippets", transcripts: ["aaaaaaaaaaa": t])[0].snippet
        XCTAssertLessThan(late.distance(from: late.startIndex, to: late.range(of: "snippets")!.lowerBound), 24, late)
        // What he or the page wrote beats the transcript: "friction" is in the
        // title AND said at 0:00 — the title is the better answer.
        var w = v; w.title = "Why I hate friction"
        XCTAssertEqual(Finder.search(Library(items: [w]), "friction", transcripts: ["aaaaaaaaaaa": t]).first?.place, .title)
        // No transcript, no said-hit.
        XCTAssertEqual(Finder.search(Library(items: [v]), "hyper key"), [])
    }

    func testFiltersNarrowTheHits() {
        var a = Video(id: "a", videoId: "aaaaaaaaaaa", url: "u", title: "Sleep one")
        a.watchedAt = Date(); a.body = "noted"
        let b = Video(id: "b", videoId: nil, url: "https://e.com", title: "Sleep two", kind: .article)
        let lib = Library(items: [a, b])
        var f = FindFilter()
        XCTAssertEqual(Finder.search(lib, "sleep", filter: f).count, 2)
        f.place = .library
        XCTAssertEqual(Finder.search(lib, "sleep", filter: f).map(\.item.id), ["a"])
        f = FindFilter(); f.kind = .article
        XCTAssertEqual(Finder.search(lib, "sleep", filter: f).map(\.item.id), ["b"])
        f = FindFilter(); f.withNotes = true
        XCTAssertEqual(Finder.search(lib, "sleep", filter: f).map(\.item.id), ["a"])
    }

    func testTranscriptShelfRemembersAndRetriesAfterAWeek() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let shelf = TranscriptShelf(folder: dir)
        XCTAssertTrue(shelf.needsFetch("aaaaaaaaaaa"))
        shelf.write(Transcript(videoId: "aaaaaaaaaaa", lines: [.init(t: 1000, s: "hello")]))
        XCTAssertFalse(shelf.needsFetch("aaaaaaaaaaa"))
        XCTAssertEqual(shelf.read("aaaaaaaaaaa")?.lines.first?.s, "hello")
        shelf.markNone("bbbbbbbbbbb", now: Date())
        XCTAssertFalse(shelf.needsFetch("bbbbbbbbbbb"), "no captions: not asked again at once")
        XCTAssertTrue(shelf.needsFetch("bbbbbbbbbbb", now: Date().addingTimeInterval(8 * 86_400)), "but again after a week")
        XCTAssertNil(shelf.read("bbbbbbbbbbb"))
        XCTAssertEqual(Array(shelf.all().keys), ["aaaaaaaaaaa"])
    }

    func testSavedSearchesTravelAndMergeLikeCards() throws {
        let old = #"{"items":[]}"#
        XCTAssertEqual(try JSONDecoder.watchLater.decode(Library.self, from: Data(old.utf8)).searches, [])
        let q1 = SavedSearch(id: "q1", query: "sleep", createdAt: Date(timeIntervalSince1970: 100))
        var mac = Library(); mac.searches = [q1]
        var phone = Library(); phone.searches = [q1, SavedSearch(id: "q2", query: "raycast", createdAt: Date(timeIntervalSince1970: 200))]
        phone.searches[0].deletedAt = Date(); phone.searches[0].modifiedAt = Date()
        let m = Library.merged(mac, phone)
        XCTAssertEqual(m.liveSearches.map(\.query), ["raycast"], "a removal on the phone is not undone by the Mac")
        let again = try JSONDecoder.watchLater.decode(Library.self, from: JSONEncoder.watchLater.encode(m))
        XCTAssertEqual(again.searches.count, 2)
    }
}
