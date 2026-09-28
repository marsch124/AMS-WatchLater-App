import XCTest

/// Two tests to begin with, and one more added at a time.
///
/// Every control is found by its accessibility identifier — never by the words
/// on it — so rewording a button can never turn the suite red. The same file
/// runs on the iPhone simulator and on the Mac.
final class WatchLaterUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]          // a fresh, throwaway list, no network
        if seeded { app.launchArguments += ["-seed"] }  // three videos of known lengths
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement? {
        for q in [app.buttons[id], app.otherElements[id], app.staticTexts[id], app.textFields[id]] where q.exists {
            return q
        }
        return nil
    }

    private func waitFor(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element(app, id) != nil { return true }
            usleep(200_000)
        }
        // Facts before theories: when a wait fails, say what WAS on screen.
        // The Mac's menu bar alone fills pages, so show the windows only.
        let windows = app.windows.allElementsBoundByIndex
        print("WL-TREE (waiting for \(id)): \(windows.count) window(s)")
        for w in windows.prefix(3) { print(String(w.debugDescription.prefix(4000))) }
        return false
    }

    /// Taps once it is there and hittable; a control that is on screen but
    /// reports itself unhittable is tapped where it is.
    /// A control below the fold exists but is not hittable, and a tap at its
    /// coordinate lands off screen and does nothing (test 3 found that out) —
    /// so scroll until it is really there, and only then tap.
    #if os(macOS)
    private var macWheel: CGFloat = -300
    #endif

    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20, line: UInt = #line) {
        var deadline = Date().addingTimeInterval(timeout)
        var scrolls = 0
        while Date() < deadline {
            if let e = element(app, id) {
                if e.isHittable { e.tap(); return }
                // The tab bar never scrolls; the Mac calls its buttons "not
                // hittable" anyway (CI 2026-09-28), so click where they are.
                if id.hasPrefix("tab-") {
                    e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    return
                }
                if scrolls < 12 {
                    #if os(macOS)
                    // A swipe does not scroll on the Mac (CI 2026-09-28: "Link to…"
                    // sat under the card sheet's edge). Scroll the view that holds
                    // the control — the sheet's, not the window's behind it — and
                    // if it did not move, the wheel goes the other way.
                    let holder = app.scrollViews.containing(.any, identifier: id).allElementsBoundByIndex.last
                        ?? app.scrollViews.firstMatch
                    let before = e.frame.minY
                    holder.scroll(byDeltaX: 0, deltaY: macWheel)
                    if abs(e.frame.minY - before) < 1 { macWheel = -macWheel }
                    #else
                    // The scroll view that HOLDS the control: "the first one" was
                    // sometimes one lying off screen (x −426), so the swipe failed
                    // and the time ran out (flaky on CI and locally, 2026-09-28).
                    let holder = app.scrollViews.containing(.any, identifier: id).allElementsBoundByIndex
                        .last { $0.frame.minX > -1 && $0.frame.minX < app.frame.maxX }
                    if let holder { holder.swipeUp(velocity: .slow) } else { app.swipeUp() }
                    #endif
                    scrolls += 1
                    // Each scroll earns its own time: on a slow CI runner one
                    // look at the screen took 4–8 s, and a 20 s budget ran out
                    // after a single scroll (TestFlight run 36426324363).
                    deadline = max(deadline, Date().addingTimeInterval(15))
                    continue
                }
                e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                return
            }
            usleep(200_000)
        }
        let windows = app.windows.allElementsBoundByIndex
        print("WL-TREE (tapping \(id)): \(windows.count) window(s)")
        for w in windows.prefix(2) { print(String(w.debugDescription.suffix(5000))) }
        XCTFail("nothing with identifier \(id)", line: line)
    }

    /// Tap, then wait for what the tap should bring. On a slow runner a tap can
    /// land while the list redraws (right after typing) and be lost — the same
    /// tap by hand works — so a lost tap is tried again, at most three times.
    private func tap(_ app: XCUIApplication, _ id: String, bringing next: String, line: UInt = #line) -> Bool {
        for _ in 0..<3 {
            tap(app, id, line: line)
            if waitFor(app, next, timeout: 8) { return true }
            if absent(app, id) { break }
        }
        return waitFor(app, next, timeout: 5)
    }

    private func absent(_ app: XCUIApplication, _ id: String) -> Bool { element(app, id) == nil }

    private func waitForAbsence(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if absent(app, id) { return true }
            usleep(200_000)
        }
        return false
    }

    /// Test 1 — a fresh list says so, and the one big button is there.
    func testAFreshListSaysNothingIsWaiting() {
        let app = launch(seeded: false)
        XCTAssertTrue(waitFor(app, "wl-add"), "the Add button is the app's one main action")
        XCTAssertTrue(waitFor(app, "wl-empty"), "an empty list says so instead of showing nothing")
    }

    /// Test 2 — the thing the app is for: "I have five minutes" shows only what fits.
    func testFiveMinutesShowsOnlyWhatFits() {
        let app = launch(seeded: true)
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfour000"), "the seeded list should be on screen")
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfifty00"))

        tap(app, "wl-bucket-five")
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfour000"), "a four-minute video fits five minutes")
        XCTAssertTrue(absent(app, "wl-open-seed-seedfifteen"), "fifteen minutes does not")
        XCTAssertTrue(absent(app, "wl-open-seed-seedfifty00"), "nor does fifty")

        tap(app, "wl-bucket-twenty")
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfifteen"), "twenty minutes takes the fifteen back in")
        XCTAssertTrue(absent(app, "wl-open-seed-seedfifty00"))
    }

    /// Test 3 — the knowledge base's first brick: open a card, mark a moment,
    /// and the mark is there, at its time, beside the two it already had.
    func testMarkingAMomentKeepsIt() {
        let app = launch(seeded: true)
        tap(app, "wl-open-seed-seedfifteen")
        XCTAssertTrue(waitFor(app, "wl-mark-jump-1"), "the page shows the two seeded marks")
        XCTAssertTrue(absent(app, "wl-mark-jump-2"))

        // Pressed with nothing in it, the button says what is missing.
        tap(app, "wl-mark-add")
        XCTAssertTrue(waitFor(app, "wl-mark-missing"), "an empty mark is refused with a reason")

        tap(app, "wl-mark-time")
        app.typeText("12:34")
        tap(app, "wl-mark-text")
        // Return adds the mark — on a phone the keyboard hides the Mark button,
        // and CI's iPhone failed exactly there when this pressed the button.
        app.typeText("The bit about window layouts\n")

        XCTAssertTrue(waitFor(app, "wl-mark-jump-2"), "the new mark is listed, after 6:52 by its time")
        XCTAssertTrue(absent(app, "wl-mark-missing"), "and the reason is gone")
    }

    /// Test 4 — the tabs: a card ticked on Watch leaves Watch and turns up in
    /// the Library tab.
    func testATickedCardMovesToTheLibraryTab() {
        let app = launch(seeded: true)
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfour000"), "the four-minute video waits on Watch")
        tap(app, "wl-tick-seed-seedfour000")
        XCTAssertTrue(waitForAbsence(app, "wl-open-seed-seedfour000"), "ticked, it leaves Watch")

        tap(app, "tab-library")
        XCTAssertTrue(waitFor(app, "wl-screen-library"), "the Library tab opens")
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedfour000"), "and the ticked video is in it")
        XCTAssertTrue(waitFor(app, "wl-open-seed-seedlecture"), "beside what was there already")
    }

    /// Test 5 — Finding: words that were only SAID in a video (its seeded
    /// transcript), never written anywhere, find it, and the result opens the
    /// video's page.
    func testFindSearchesWhatWasSaid() {
        let app = launch(seeded: true)
        tap(app, "tab-find")
        XCTAssertTrue(waitFor(app, "wl-screen-find"), "the Find tab opens")
        tap(app, "wl-find-field")
        app.typeText("changes everything")
        // "changes everything" is written nowhere — no title, tag, mark or note has it.
        // Only the seeded transcript of the fifteen-minute video says it.
        XCTAssertTrue(waitFor(app, "wl-hit-seed-seedfifteen"), "the video that said it is found")
        XCTAssertTrue(absent(app, "wl-hit-seed-seedfour000"), "the others never said it")
        XCTAssertTrue(tap(app, "wl-hit-seed-seedfifteen", bringing: "wl-said-toggle"),
                      "the video's page opens, with What was said")
    }

    /// Test 6 — Connecting: link one card to another, walk to it, and the
    /// other card shows the link back; the back button returns.
    func testALinkConnectsBothCards() {
        let app = launch(seeded: true)
        tap(app, "wl-open-seed-seedfifteen")
        XCTAssertTrue(absent(app, "wl-conn-seed-seedfour000"), "nothing is connected yet")
        XCTAssertTrue(tap(app, "wl-link-add", bringing: "wl-link-pick-seed-seedfour000"), "the picker lists the others")
        XCTAssertTrue(tap(app, "wl-link-pick-seed-seedfour000", bringing: "wl-conn-seed-seedfour000"),
                      "the linked card is listed")

        XCTAssertTrue(tap(app, "wl-conn-seed-seedfour000", bringing: "wl-item-back"), "the linked card opens, with a way back")
        XCTAssertTrue(waitFor(app, "wl-conn-seed-seedfifteen"), "and it links back by itself")

        XCTAssertTrue(tap(app, "wl-item-back", bringing: "wl-link-remove-seed-seedfour000"),
                      "back on the first card, the link is its own")
        XCTAssertTrue(absent(app, "wl-item-back"), "at the start of the trail there is no back")
    }
}
