import XCTest
@testable import WatchLaterCore

final class YouTubeTests: XCTestCase {

    func testVideoIdFromEveryShapeOfLink() {
        XCTAssertEqual(YouTube.videoId(in: "https://www.youtube.com/watch?v=m5MDv9qwhU8"), "m5MDv9qwhU8")
        XCTAssertEqual(YouTube.videoId(in: "https://www.youtube.com/watch?list=PLx&v=m5MDv9qwhU8&t=12s"), "m5MDv9qwhU8")
        XCTAssertEqual(YouTube.videoId(in: "https://youtu.be/m5MDv9qwhU8?si=abc"), "m5MDv9qwhU8")
        XCTAssertEqual(YouTube.videoId(in: "https://youtube.com/shorts/aB_c-D12345"), "aB_c-D12345")
        XCTAssertEqual(YouTube.videoId(in: "https://www.youtube.com/live/aB_c-D12345"), "aB_c-D12345")
        XCTAssertNil(YouTube.videoId(in: "https://www.youtube.com/playlist?list=PL123"))
        XCTAssertNil(YouTube.videoId(in: "https://example.com"))
    }

    func testShortsAndPlaylists() {
        XCTAssertTrue(YouTube.isShortLink("https://youtube.com/shorts/aB_c-D12345"))
        XCTAssertFalse(YouTube.isShortLink("https://www.youtube.com/watch?v=m5MDv9qwhU8"))
        XCTAssertEqual(YouTube.playlistId(in: "https://www.youtube.com/playlist?list=PLabc_-1"), "PLabc_-1")
        XCTAssertTrue(YouTube.isBarePlaylist("https://www.youtube.com/playlist?list=PLabc"))
        XCTAssertFalse(YouTube.isBarePlaylist("https://www.youtube.com/watch?v=m5MDv9qwhU8&list=PLabc"))
    }

    func testLinksInPastedText() {
        let text = """
        Look at these: https://youtu.be/m5MDv9qwhU8, and
        https://www.youtube.com/watch?v=aB_c-D12345).
        https://youtu.be/m5MDv9qwhU8 again
        """
        XCTAssertEqual(YouTube.links(in: text),
                       ["https://youtu.be/m5MDv9qwhU8", "https://www.youtube.com/watch?v=aB_c-D12345"])
    }

    func testWatchPageParsing() {
        let html = """
        <meta name="title" content="Max &amp; Co &quot;live&quot;"><script>
        var x = {"lengthSeconds":"915","ownerChannelName":"Raycast"}</script>
        """
        let m = YouTube.parseWatchPage(html)
        XCTAssertEqual(m.seconds, 915)
        XCTAssertEqual(m.title, "Max & Co \"live\"")
        XCTAssertEqual(m.channel, "Raycast")
    }

    func testWatchPageFallsBackToIsoDuration() {
        let m = YouTube.parseWatchPage(#"<meta itemprop="duration" content="PT1H2M3S">"#)
        XCTAssertEqual(m.seconds, 3723)
        XCTAssertNil(m.title)
    }

    func testOEmbed() {
        let data = #"{"title":"A title","author_name":"A channel"}"#.data(using: .utf8)!
        XCTAssertEqual(YouTube.parseOEmbed(data), YouTube.Meta(title: "A title", channel: "A channel"))
        XCTAssertEqual(YouTube.parseOEmbed(Data("nope".utf8)), YouTube.Meta())
    }

    /// The badge sits BEFORE its row's id — the bug the web app had for a day.
    func testPlaylistRowsTakeTheBadgeBeforeTheirOwnId() {
        let html = """
        {"text":"4:10"} filler {"contentId":"aaaaaaaaaaa","contentType":"LOCKUP_CONTENT_TYPE_VIDEO"}
        {"text":"12:00"} {"text":"1:02:03"} {"contentId":"bbbbbbbbbbb","contentType":"LOCKUP_CONTENT_TYPE_VIDEO"}
        {"contentId":"ccccccccccc","contentType":"LOCKUP_CONTENT_TYPE_VIDEO"}
        {"contentId":"aaaaaaaaaaa","contentType":"LOCKUP_CONTENT_TYPE_VIDEO"}
        """
        let rows = YouTube.parsePlaylistPage(html)
        XCTAssertEqual(rows, [
            .init(id: "aaaaaaaaaaa", seconds: 250),
            .init(id: "bbbbbbbbbbb", seconds: 3723),
            .init(id: "ccccccccccc", seconds: nil),
        ])
    }

    func testPlaylistFallbackToAnyVideoId() {
        let rows = YouTube.parsePlaylistPage(#"{"videoId":"aaaaaaaaaaa"} {"videoId":"aaaaaaaaaaa"} {"videoId":"bbbbbbbbbbb"}"#)
        XCTAssertEqual(rows.map(\.id), ["aaaaaaaaaaa", "bbbbbbbbbbb"])
    }

    func testClocksAndIso() {
        XCTAssertEqual(YouTube.clockToSeconds("4:10"), 250)
        XCTAssertEqual(YouTube.clockToSeconds("1:02:03"), 3723)
        XCTAssertNil(YouTube.clockToSeconds("live"))
        XCTAssertEqual(YouTube.isoToSeconds("PT5M"), 300)
        XCTAssertNil(YouTube.isoToSeconds("5 min"))
    }

    func testTagsAreCleanedNotTaxonomised() {
        XCTAssertEqual(YouTube.cleanTags([" Raycast", "raycast", "", "Health"]), ["Raycast", "Health"])
    }

    func testPlaylistLink() {
        XCTAssertEqual(YouTube.playlistLink(for: ["a", "b"]),
                       "https://www.youtube.com/watch_videos?video_ids=a,b")
    }
}
