import XCTest
@testable import WatchLaterCore

/// Step 3 — Connecting: links he makes, links written as [[Title]], the
/// way back, and what might belong together.
final class ConnectingTests: XCTestCase {

    func card(_ id: String, _ title: String, channel: String = "", tags: [String] = []) -> Video {
        Video(id: id, videoId: nil, url: "https://e.com/\(id)", title: title, channel: channel, tags: tags)
    }

    func testWikiTitlesReadObsidiansSpelling() {
        XCTAssertEqual(Connections.wikiTitles(in: "see [[Why we sleep]] and [[Knots|the knot one]]."),
                       ["Why we sleep", "Knots"])
        XCTAssertEqual(Connections.wikiTitles(in: "no links [here] or [[\n]]"), [])
    }

    func testALinkShowsOnBothCardsOnce() {
        var a = card("a", "Four minutes on knots")
        let b = card("b", "Why we sleep")
        a.links = ["b"]
        let lib = Library(items: [a, b])
        XCTAssertEqual(Connections.all(a, in: lib).map(\.item.id), ["b"])
        XCTAssertEqual(Connections.all(a, in: lib).first?.way, .to)
        XCTAssertEqual(Connections.all(a, in: lib).first?.made, true)
        // The way back — b never linked, yet it knows a points at it.
        XCTAssertEqual(Connections.all(b, in: lib).map(\.item.id), ["a"])
        XCTAssertEqual(Connections.all(b, in: lib).first?.way, .from)
        // Linked both ways: one row, not two.
        var b2 = b; b2.links = ["a"]
        let both = Connections.all(a, in: Library(items: [a, b2]))
        XCTAssertEqual(both.count, 1)
        XCTAssertEqual(both.first?.way, .both)
    }

    func testANoteLinksByTitleAccentBlindAndGoneCardsDropOut() {
        var a = card("a", "Notes")
        a.body = "Like [[hjarnans vikt]] said. Also [[Nothing by that name]]."
        var b = card("b", "Hjärnans vikt")
        let lib = Library(items: [a, b])
        let out = Connections.all(a, in: lib)
        XCTAssertEqual(out.map(\.item.id), ["b"], "the unknown title makes no link")
        XCTAssertEqual(out.first?.made, false, "written, not made — nothing to remove with the button")
        XCTAssertEqual(Connections.all(b, in: lib).map(\.item.id), ["a"])
        b.deletedAt = Date()
        XCTAssertEqual(Connections.all(a, in: Library(items: [a, b])), [], "a removed card is not offered")
    }

    func testRelatedPrefersSharedTagsThenChannelThenWordsAndSkipsWhatIsLinked() {
        var me = card("me", "Sleep and memory", channel: "Huberman", tags: ["Brain"])
        let tag = card("tag", "Cold water", tags: ["brain"])
        let chan = card("chan", "Focus", channel: "Huberman")
        let word = card("word", "A memory palace")
        let none = card("none", "Four minutes on knots")
        var lib = Library(items: [me, tag, chan, word, none])
        XCTAssertEqual(Connections.related(to: me, in: lib).map(\.id), ["tag", "chan"],
                       "one shared word alone is not enough")
        me.links = ["tag"]
        lib = Library(items: [me, tag, chan, word, none])
        XCTAssertEqual(Connections.related(to: me, in: lib).map(\.id), ["chan"], "already linked is not suggested")
    }

    func testRelatedTopicsShareCards() {
        let lib = Library(items: [card("1", "x", tags: ["Sleep", "Brain"]), card("2", "y", tags: ["Brain", "Cold"]),
                                  card("3", "z", tags: ["Brain", "Cold"]), card("4", "w", tags: ["Knots"])])
        let brain = Topics.all(lib).first { $0.name == "Brain" }!
        let rel = Connections.relatedTopics(brain, in: lib)
        XCTAssertEqual(rel.map(\.topic.name), ["Cold", "Sleep"])
        XCTAssertEqual(rel.map(\.shared), [2, 1])
    }

    func testLinksTravelInTheFileAndOldFilesReadWithout() throws {
        var a = card("a", "A"); a.links = ["b"]
        let data = try JSONEncoder.watchLater.encode(Library(items: [a]))
        XCTAssertEqual(try JSONDecoder.watchLater.decode(Library.self, from: data).items.first?.links, ["b"])
        let old = #"{"items":[{"id":"x","url":"u","title":"t"}]}"#
        XCTAssertEqual(try JSONDecoder.watchLater.decode(Library.self, from: Data(old.utf8)).items.first?.links, [])
    }
}
