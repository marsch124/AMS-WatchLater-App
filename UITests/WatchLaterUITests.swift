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
        return false
    }

    /// Taps once it is there and hittable; a control that is on screen but
    /// reports itself unhittable is tapped where it is.
    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let e = element(app, id) {
                if e.isHittable { e.tap() } else { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                return
            }
            usleep(200_000)
        }
        XCTFail("nothing with identifier \(id)", line: line)
    }

    private func absent(_ app: XCUIApplication, _ id: String) -> Bool { element(app, id) == nil }

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
}
