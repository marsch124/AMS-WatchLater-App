import XCTest
@testable import WatchLaterCore

/// Step 4 — Learning more: marks come back at widening gaps, long transcripts
/// are read in pieces, summaries travel in the file, "find more" searches.
final class LearningTests: XCTestCase {
    let day: TimeInterval = 86_400
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func card(_ id: String, marks: [Mark]) -> Video {
        var v = Video(id: id, videoId: nil, url: "u", title: id); v.marks = marks; return v
    }

    func testAMarkComesBackAfterADayThenAtWideningGaps() {
        let fresh = Mark(seconds: 1, text: "fresh", createdAt: now.addingTimeInterval(-0.5 * day))
        let old = Mark(seconds: 2, text: "old", createdAt: now.addingTimeInterval(-2 * day))
        let empty = Mark(seconds: 3, text: "  ", createdAt: now.addingTimeInterval(-9 * day))
        let lib = Library(items: [card("a", marks: [fresh, old, empty])])
        XCTAssertEqual(Review.due(lib, now: now).map(\.mark.text), ["old"], "a day old, and only with words")

        let r1 = Review.remembered(old, now: now)
        XCTAssertEqual(r1.reviewStep, 1)
        XCTAssertEqual(Review.next(r1), now.addingTimeInterval(3 * day), "remembered once: three days")
        XCTAssertEqual(Review.next(Review.remembered(r1, now: now)), now.addingTimeInterval(7 * day), "twice: a week")
        let a = Review.again(Review.remembered(r1, now: now), now: now)
        XCTAssertEqual(Review.next(a), now.addingTimeInterval(1 * day), "Again starts over")
        var top = old; top.reviewStep = 99
        XCTAssertEqual(Review.next(Review.remembered(top, now: now)), now.addingTimeInterval(180 * day), "gaps stop at half a year")
    }

    func testAFewADayLongestWaitingFirst() {
        let marks = (0..<9).map { Mark(seconds: $0, text: "m\($0)", createdAt: now.addingTimeInterval(-Double(20 - $0) * day)) }
        var gone = card("gone", marks: [Mark(seconds: 0, text: "removed card", createdAt: now.addingTimeInterval(-99 * day))])
        gone.deletedAt = now
        let due = Review.due(Library(items: [card("a", marks: marks), gone]), now: now)
        XCTAssertEqual(due.count, Review.perDay)
        XCTAssertEqual(due.map(\.mark.text), ["m0", "m1", "m2", "m3", "m4"])
    }

    func testLongTranscriptsAreReadInPiecesAtLineBreaks() {
        let lines = (0..<10).map { Transcript.Line(t: $0 * 1000, s: "one two three four") }  // 40 words
        let p = Reading.pieces(lines, wordsPerPiece: 12)
        XCTAssertEqual(p.count, 4, "12 words a piece, 4 words a line: 3 lines, 3, 3, 1")
        XCTAssertEqual(p.first?.split(separator: " ").count, 12)
        XCTAssertEqual(p.joined(separator: " ").split(separator: " ").count, 40, "nothing lost")
        XCTAssertEqual(Reading.pieces([]), [])
    }

    func testFindMoreSearchesTheTellingWords() {
        let v = Video(videoId: "x", url: "u", title: "Fifteen minutes of Raycast: the Hyper key, episode 12")
        XCTAssertEqual(Research.query(for: v), "Fifteen Raycast Hyper key")
        XCTAssertEqual(Research.youTube("sömn & minne")?.absoluteString,
                       "https://www.youtube.com/results?search_query=s%C3%B6mn%20%26%20minne")
    }

    func testDigestAndReviewTravelInTheFileAndOldFilesReadWithout() throws {
        var v = card("a", marks: [Review.remembered(Mark(seconds: 1, text: "x", createdAt: now), now: now)])
        v.digest = Digest(summary: "S", points: ["p"], questions: [.init(question: "q?", answer: "a")], madeAt: now)
        let back = try JSONDecoder.watchLater.decode(Library.self, from: JSONEncoder.watchLater.encode(Library(items: [v])))
        XCTAssertEqual(back.items.first?.digest, v.digest)
        XCTAssertEqual(back.items.first?.marks.first?.reviewStep, 1)
        let old = #"{"items":[{"id":"x","url":"u","title":"t","marks":[{"id":"m","seconds":3,"text":"hi","createdAt":"2026-09-01T10:00:00Z"}]}]}"#
        let o = try JSONDecoder.watchLater.decode(Library.self, from: Data(old.utf8)).items.first
        XCTAssertNil(o?.digest)
        XCTAssertNil(o?.marks.first?.reviewStep)
    }

    /// Two real answers from the on-device model (2026-09-28): markdown
    /// headings with colons, "*   " bullets, "Q:  " with double spaces.
    func testTheModelsAnswerIsReadBackWhateverItsDecoration() {
        let swedish = """
        ### SUMMARY:

        Anders Hansen diskuterar hur AI påverkar hjärnan. Han betonar riskerna.

        ### KEY POINTS:

        *   AI kan påverka sociala färdigheter.
        *   AI Act kräver transparens.

        ### QUESTIONS:

        Q:  Vad säger Hansen om AI?
        A:  Att det kan öka ensamheten.

        Q:  Vad kräver AI Act?
        A:  Transparens.
        """
        let d = Digest.parse(swedish)
        XCTAssertEqual(d?.summary, "Anders Hansen diskuterar hur AI påverkar hjärnan. Han betonar riskerna.")
        XCTAssertEqual(d?.points, ["AI kan påverka sociala färdigheter.", "AI Act kräver transparens."])
        XCTAssertEqual(d?.questions, [.init(question: "Vad säger Hansen om AI?", answer: "Att det kan öka ensamheten."),
                                      .init(question: "Vad kräver AI Act?", answer: "Transparens.")])

        let other = """
        **Summary:** Shoulder pain in swimmers comes from imbalance.
        ## KEY POINTS
        - Strengthen the rotators.
        1. Do 3 sets.
        ## QUESTIONS
        Q1: How many sets?
        A1: Three.
        """
        let e = Digest.parse(other)
        XCTAssertEqual(e?.summary, "Shoulder pain in swimmers comes from imbalance.")
        XCTAssertEqual(e?.points, ["Strengthen the rotators.", "Do 3 sets."])
        XCTAssertEqual(e?.questions.first?.answer, "Three.")
        // A real answer with no SUMMARY heading at all — it just starts.
        let bare = """
        This video explains how to use Raycast. It saves time.

        **KEY POINTS**

        - Hyper key is Caps Lock.

        **QUESTIONS**

        Q: What is the Hyper key?
        A: Caps Lock.
        """
        XCTAssertEqual(Digest.parse(bare)?.summary, "This video explains how to use Raycast. It saves time.")
        XCTAssertEqual(Digest.parse(bare)?.points, ["Hyper key is Caps Lock."])
        XCTAssertEqual(Digest.parse("KEY POINTS:\n- only points")?.summary, nil, "no summary, nothing to keep")
        let eight = "SUMMARY: s\nKEY POINTS:\n" + (1...8).map { "- p\($0)" }.joined(separator: "\n")
        XCTAssertEqual(Digest.parse(eight)?.points.count, 6, "a short list stays short")
                XCTAssertEqual(Reading.wordCount([.init(t: 0, s: "one two"), .init(t: 1, s: "three")]), 3)
    }
}
