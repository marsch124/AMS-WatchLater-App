import XCTest
@testable import WatchLaterCore

/// The models behind the Find, Library and Topics tabs.
final class TabsModelTests: XCTestCase {

    private func v(_ id: String, _ title: String, done daysAgo: Double? = nil, tags: [String] = [],
                   kind: ItemKind = .video) -> Video {
        var x = Video(id: id, videoId: kind == .video ? id.padding(toLength: 11, withPad: "x", startingAt: 0) : nil,
                      url: "https://e.com/\(id)", title: title, kind: kind)
        x.tags = tags
        if let d = daysAgo { x.watchedAt = Date().addingTimeInterval(-d * 86_400) }
        return x
    }

    // MARK: Find

    func testFindSaysWhereItMatchedTitleFirst() {
        var a = v("a", "Sleep and memory")
        a.marks = [Mark(seconds: 95, text: "sleep pressure builds all day")]
        var b = v("b", "Swimming drills")
        b.marks = [Mark(seconds: 412, text: "Breathe out slowly before the turn")]
        var c = v("c", "Raycast tips", done: 2)
        c.body = "Try the sleep timer extension"
        let hits = Finder.search(Library(items: [a, b, c]), "sleep")
        XCTAssertEqual(hits.map(\.item.id), ["a", "c"], "waiting before Library; b does not mention it")
        XCTAssertEqual(hits[0].place, .title, "a title match wins over a mark in the same item")
        XCTAssertEqual(hits[1].place, .body)

        let breathe = Finder.search(Library(items: [a, b, c]), "breathe")
        XCTAssertEqual(breathe.first?.place, .mark(seconds: 412), "a mark hit carries its moment")
    }

    func testFindIsAccentBlindAndIgnoresOneLetter() {
        var a = v("a", "Anders Hansen")
        a.note = "Hjärnans akilleshälar"
        XCTAssertEqual(Finder.search(Library(items: [a]), "hjarnans").first?.place, .note)
        XCTAssertEqual(Finder.search(Library(items: [a]), "h"), [], "one letter matches everything — wait for two")
    }

    func testSnippetKeepsWordsWholeAndShowsCuts() {
        let text = "The first part is long and boring, then comes insulin, and after that a very long tail of words."
        let s = Finder.snippet(text, "insulin", radius: 16)!
        XCTAssertEqual(s.match, "insulin")
        XCTAssertTrue(s.text.hasPrefix("…"), s.text)
        XCTAssertTrue(s.text.hasSuffix("…"), s.text)
        XCTAssertTrue(s.text.contains("comes insulin, and"), s.text)
        let words = Set(text.split(separator: " ").map(String.init))
        for w in s.text.replacingOccurrences(of: "…", with: "").split(separator: " ") {
            XCTAssertTrue(words.contains(String(w)), "half a word in the snippet: '\(w)' in \(s.text)")
        }
        XCTAssertEqual(Finder.snippet("Sömn", "somn")?.match, "Sömn", "his spelling is kept")
        XCTAssertNil(Finder.snippet("", "x"))
    }

    // MARK: Library

    func testLibraryGroupsByWhenItWasFinished() {
        var noted = v("n", "Noted", done: 20)
        noted.marks = [Mark(seconds: 1, text: "x")]
        let lib = Library(items: [v("w", "Week", done: 1), noted, v("e", "Earlier", done: 90),
                                  v("open", "Still waiting")])
        let g = LibraryShelf.groups(lib)
        XCTAssertEqual(g.map(\.title), ["This week", "This month", "Earlier"])
        XCTAssertEqual(g.flatMap(\.items).map(\.id), ["w", "n", "e"], "waiting things are not in the Library")
        XCTAssertEqual(LibraryShelf.groups(lib, filter: .withNotes).flatMap(\.items).map(\.id), ["n"])
        XCTAssertEqual(LibraryShelf.markCount(lib), 1)
    }

    // MARK: Topics

    func testATopicPerTagSpelledAsFirstWritten() {
        let lib = Library(items: [
            v("a", "A", tags: ["Raycast"]), v("b", "B", done: 3, tags: ["raycast", "AI"]),
            v("c", "C", tags: ["AI"], kind: .article), v("d", "D", tags: ["Raycast"]),
        ])
        let t = Topics.all(lib)
        XCTAssertEqual(t.map(\.name), ["Raycast", "AI"], "biggest first; one topic for Raycast/raycast")
        XCTAssertEqual(t[0].items.last?.id, "b", "the Library item comes after the waiting ones")
        XCTAssertEqual(t[0].waiting, 2)
        XCTAssertEqual(t[1].summary, "1 video · 1 article")
    }
}
