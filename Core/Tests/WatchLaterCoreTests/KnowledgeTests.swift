import XCTest
@testable import WatchLaterCore

/// The 0.2 knowledge fields: kinds, marks, long notes, pages.
final class KnowledgeTests: XCTestCase {

    // MARK: Old files still read, new fields default quietly

    func testAnOldCardBecomesAVideoWithNoMarks() throws {
        let json = #"{"items":[{"id":"a","videoId":"aaaaaaaaaaa","url":"u","title":"T","savedAt":"2026-09-01T10:00:00Z"},{"id":"b","url":"https://example.com","title":"P","savedAt":"2026-09-01T10:00:00Z"}]}"#
        let lib = try JSONDecoder.watchLater.decode(Library.self, from: Data(json.utf8))
        XCTAssertEqual(lib.items[0].kind, .video)
        XCTAssertEqual(lib.items[1].kind, .page, "no video id means a page")
        XCTAssertEqual(lib.items[0].marks, [])
        XCTAssertEqual(lib.items[0].body, "")
        XCTAssertFalse(lib.items[0].hasNotes)
    }

    func testMarksAndTheLongNoteSurviveTheFile() throws {
        var v = Video(videoId: "aaaaaaaaaaa", url: YouTube.watchURL(for: "aaaaaaaaaaa"), title: "T")
        v.marks = [Mark(seconds: 754, text: "sleep"), Mark(seconds: nil, text: "a thought")]
        v.body = "# Heading\n\n- a point"
        let again = try JSONDecoder.watchLater.decode(Library.self,
                        from: JSONEncoder.watchLater.encode(Library(items: [v])))
        XCTAssertEqual(again.items[0].marks.map(\.text), ["sleep", "a thought"])
        XCTAssertEqual(again.items[0].marks[0].seconds, 754)
        XCTAssertEqual(again.items[0].body, v.body)
        XCTAssertTrue(again.items[0].hasNotes)
    }

    // MARK: Marks

    func testMarksSortByMomentThenUntimedByWhenWritten() {
        var v = Video(videoId: "aaaaaaaaaaa", url: "u", title: "T")
        let t0 = Date(timeIntervalSince1970: 1000)
        v.marks = [Mark(id: "late", seconds: 600, text: "", createdAt: t0),
                   Mark(id: "note2", seconds: nil, text: "", createdAt: t0.addingTimeInterval(20)),
                   Mark(id: "early", seconds: 30, text: "", createdAt: t0.addingTimeInterval(5)),
                   Mark(id: "note1", seconds: nil, text: "", createdAt: t0.addingTimeInterval(10))]
        XCTAssertEqual(v.sortedMarks.map(\.id), ["early", "late", "note1", "note2"])
    }

    func testAMarkLinksToItsMomentOnYouTube() {
        let v = Video(videoId: "m5MDv9qwhU8", url: YouTube.watchURL(for: "m5MDv9qwhU8"), title: "T")
        XCTAssertEqual(v.url(at: 754)?.absoluteString, "https://www.youtube.com/watch?v=m5MDv9qwhU8&t=754s")
        XCTAssertEqual(v.url(at: nil)?.absoluteString, "https://www.youtube.com/watch?v=m5MDv9qwhU8")
        let page = Video(videoId: nil, url: "https://example.com/a", title: "P")
        XCTAssertEqual(page.url(at: 30)?.absoluteString, "https://example.com/a", "a page has no moments")
    }

    func testTypedMoments() {
        XCTAssertEqual(Clock.parseMoment("12:34"), 754)
        XCTAssertEqual(Clock.parseMoment("1:02:03"), 3723)
        XCTAssertEqual(Clock.parseMoment("12"), 720, "a plain number means minutes")
        XCTAssertEqual(Clock.parseMoment("1,5"), 90)
        XCTAssertNil(Clock.parseMoment(""))
        XCTAssertNil(Clock.parseMoment("soon"))
    }

    // MARK: Words and Shorts per kind

    func testAnArticleIsReadAndIsNeverAShort() {
        var a = Video(videoId: nil, url: "https://example.com", title: "A", seconds: 60, kind: .article)
        XCTAssertEqual(a.doneWord, "Read")
        XCTAssertFalse(a.countsAsShort, "a one-minute read is not a YouTube Short")
        a.kind = .podcast
        XCTAssertEqual(a.doneWord, "Watched")
        XCTAssertEqual(Video(videoId: "aaaaaaaaaaa", url: "u", title: "V").doneWord, "Watched")
    }

    // MARK: Finding, now across notes and marks

    func testSearchFindsWordsInTheLongNoteAndInMarks() {
        var a = Video(id: "a", videoId: "aaaaaaaaaaa", url: "u", title: "Nothing here")
        a.body = "Why **sömn** matters"
        var b = Video(id: "b", videoId: "bbbbbbbbbbb", url: "u", title: "Also nothing")
        b.marks = [Mark(seconds: 60, text: "Dopamine and habits")]
        let c = Video(id: "c", videoId: "ccccccccccc", url: "u", title: "Unrelated")
        let lib = Library(items: [a, b, c])
        var shelf = Shelf()
        shelf.search = "somn"
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a"])
        shelf.search = "dopamine"
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["b"])
    }

    func testKindFilterAndCounts() {
        let lib = Library(items: [
            Video(id: "v", videoId: "aaaaaaaaaaa", url: "u", title: "V", seconds: 300),
            Video(id: "a", videoId: nil, url: "https://e.com/a", title: "A", seconds: 300, kind: .article),
            Video(id: "p", videoId: nil, url: "https://e.com/p", title: "P", kind: .page),
        ])
        XCTAssertEqual(Shelf.kinds(lib).map(\.kind), [.video, .article, .page])
        var shelf = Shelf()
        shelf.kind = .article
        XCTAssertEqual(shelf.apply(to: lib).map(\.id), ["a"])
        shelf.kind = nil
        shelf.bucket = .five
        XCTAssertEqual(Set(shelf.apply(to: lib).map(\.id)), ["v", "a"], "an article's reading time fits a slot too")
    }

    // MARK: Pages

    func testAnArticleReadsItsMetaTagsAndReadingTime() {
        let words = Array(repeating: "word", count: 1150).joined(separator: " ")
        let html = """
        <html><head><title>Fallback</title>
        <meta content="How we sleep" property="og:title">
        <meta property='og:site_name' content='The Paper'>
        <meta property="og:type" content="article">
        <meta name="description" content="Sleep &amp; memory">
        <meta property="og:image" content="/img/cover.jpg">
        </head><body><nav>Home About Contact</nav><article><p>\(words)</p></article>
        <script>var lots = "of words that should not count at all"</script></body></html>
        """
        let m = Page.parse(html, url: "https://www.example.com/2026/sleep")
        XCTAssertEqual(m.title, "How we sleep")
        XCTAssertEqual(m.site, "The Paper")
        XCTAssertEqual(m.blurb, "Sleep & memory")
        XCTAssertEqual(m.imageURL, "https://www.example.com/img/cover.jpg", "a relative picture is made absolute")
        XCTAssertEqual(m.kind, .article)
        XCTAssertEqual(m.seconds, 5 * 60, "1150 words at 230 a minute is five minutes")
    }

    func testAPlainPageFallsBackToTitleAndHost() {
        let m = Page.parse("<html><head><title> A tool </title></head><body>Short.</body></html>",
                           url: "https://www.sometool.io/")
        XCTAssertEqual(m.title, "A tool")
        XCTAssertEqual(m.site, "sometool.io")
        XCTAssertEqual(m.kind, .page)
        XCTAssertNil(m.seconds, "too little text to promise a reading time")
    }

    func testAShortArticleStillPromisesAMinute() {
        let words = Array(repeating: "word", count: 90).joined(separator: " ")
        let m = Page.parse(#"<meta property="og:type" content="article"><article>\#(words)</article>"#,
                           url: "https://sive.rs/x")
        XCTAssertEqual(m.seconds, 60, "ninety words is a one-minute read, not an unknown")
    }

    func testAPodcastEpisodeTakesItsDuration() {
        let html = #"<meta property="og:title" content="Episode 12"><script type="application/ld+json">{"@type":"PodcastEpisode","duration":"PT1H4M"}</script>"#
        let m = Page.parse(html, url: "https://podcasts.apple.com/se/podcast/x/id1?i=2")
        XCTAssertEqual(m.kind, .podcast)
        XCTAssertEqual(m.seconds, 3840)
    }

    func testASharedPageLinkIsSavedAsAPage() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = LibraryFile(url: dir.appendingPathComponent("watchlater.json"))
        let lib = file.addBare(url: "https://example.com/article", version: "0.2")
        XCTAssertEqual(lib.items.first?.kind, .page)
        XCTAssertEqual(lib.items.first?.thumbKey, lib.items.first?.id, "no video id: the picture is kept under the card's id")
    }
}
