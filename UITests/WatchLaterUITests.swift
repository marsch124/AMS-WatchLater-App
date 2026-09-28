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
    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var scrolls = 0
        while Date() < deadline {
            if let e = element(app, id) {
                if e.isHittable { e.tap(); return }
                if scrolls < 12 {
                    let scroll = app.scrollViews.firstMatch
                    if scroll.exists { scroll.swipeUp(velocity: .slow) } else { app.swipeUp() }
                    scrolls += 1
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
}
