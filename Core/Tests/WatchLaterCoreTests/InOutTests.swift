import XCTest
@testable import WatchLaterCore

/// Step 5 — In/out: Obsidian notes whose links resolve, his edits never
/// overwritten, and a spreadsheet Numbers can open.
final class InOutTests: XCTestCase {

    func card(_ id: String, _ title: String, daysAgo: Double = 1) -> Video {
        Video(id: id, videoId: nil, url: "https://e.com/\(id)", title: title,
              savedAt: Date(timeIntervalSince1970: 1_800_000_000 - daysAgo * 86_400))
    }

    func testFileNamesAreSafeAndUniqueAndStay() {
        XCTAssertEqual(ObsidianExport.fileName("AI: why? [part 1] #2"), "AI why part 1 2")
        XCTAssertEqual(ObsidianExport.fileName(" ...  "), "Untitled")
        XCTAssertEqual(ObsidianExport.tag("Brain & body"), "brain-body")
        let lib = Library(items: [card("new", "Notes", daysAgo: 1), card("old", "Notes", daysAgo: 5)])
        let n = ObsidianExport.names(lib)
        XCTAssertEqual(n["old"], "Notes", "the older card keeps the plain name")
        XCTAssertEqual(n["new"], "Notes (2)")
    }

    func testACardNoteCarriesEverythingAndItsLinksResolve() {
        var a = Video(id: "a", videoId: "abcdefghijk", url: "https://www.youtube.com/watch?v=abcdefghijk",
                      title: "Sleep: the basics", channel: "Huberman", seconds: 900, tags: ["Brain & body"])
        a.marks = [Mark(seconds: 95, text: "Caffeine late")]
        a.body = "See [[Cold water]] and [[Sleep: the basics|this one]]."
        a.digest = Digest(summary: "S.", points: ["P."], questions: [.init(question: "Q?", answer: "A.")])
        var b = card("b", "Cold water"); b.links = ["a"]
        let lib = Library(items: [a, b])
        let names = ObsidianExport.names(lib)
        let t = ObsidianExport.note(for: a, in: lib, names: names).text
        XCTAssertEqual(ObsidianExport.note(for: a, in: lib, names: names).path, "Sleep the basics.md")
        XCTAssertTrue(t.hasPrefix("---\ntitle: \"Sleep: the basics\"\n"), t)
        XCTAssertTrue(t.contains("tags: [watchlater, brain-body]"))
        XCTAssertTrue(t.contains("[[Topics/Brain & body|Brain & body]]"))
        XCTAssertTrue(t.contains("- [1:35](https://www.youtube.com/watch?v=abcdefghijk&t=95s) Caffeine late"), "a mark opens at its second")
        XCTAssertTrue(t.contains("## Summary\n\nS."))
        XCTAssertTrue(t.contains("- **Q?** — A."))
        XCTAssertTrue(t.contains("See [[Cold water]] and [[Sleep the basics|this one]]."), "a title that is not the file name is re-pointed")
        XCTAssertTrue(t.contains("## Connected\n\n- [[Cold water]]"), "the way back is written too")
    }

    func testAllMakesTopicsAndAnIndex() {
        var a = card("a", "One"); a.tags = ["Sleep"]; a.watchedAt = Date()
        let paths = ObsidianExport.all(Library(items: [a, card("b", "Two")])).map(\.path)
        XCTAssertEqual(Set(paths), ["One.md", "Two.md", "Topics/Sleep.md", "WatchLater.md"])
    }

    func testHisEditsAreNeverOverwritten() {
        let n = ObsidianExport.Note(path: "One.md", text: "new text")
        let lastWritten = "old text"
        let manifest = ["One.md": ObsidianExport.fingerprint(lastWritten)]
        XCTAssertEqual(ObsidianExport.plan(n, onDisk: nil, manifest: manifest), .write, "a new note")
        XCTAssertEqual(ObsidianExport.plan(n, onDisk: "new text", manifest: manifest), .same)
        XCTAssertEqual(ObsidianExport.plan(n, onDisk: lastWritten, manifest: manifest), .write, "untouched since: update it")
        XCTAssertEqual(ObsidianExport.plan(n, onDisk: "old text + his thoughts", manifest: manifest), .keepHis)
        XCTAssertEqual(ObsidianExport.plan(n, onDisk: "a note of his own", manifest: [:]), .keepHis, "not the app's")
    }

    func testTheSpreadsheetQuotesWhatNeedsIt() {
        var a = card("a", "Hello, \"world\""); a.seconds = 90; a.tags = ["x", "y"]
        let csv = Spreadsheet.csv(Library(items: [a]))
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}Title,"), "Excel needs the mark to read å ä ö")
        let rows = String(csv.dropFirst()).components(separatedBy: "\r\n")
        XCTAssertEqual(rows.first, "Title,Link,Channel,Kind,Minutes,Saved,Watched or read,Tags,Marks,Note,Summary")
        XCTAssertTrue(rows[1].hasPrefix("\"Hello, \"\"world\"\"\",https://e.com/a,,page,2,"), rows[1])
        XCTAssertTrue(rows[1].contains(",x; y,0,,"))
    }
}
