import XCTest

/// The unlock code, set and taken away with a finger (ADR 0012).
///
/// It runs only while nothing is running, which is every simulator these tests
/// can reach: none of them grants authorization, so none can commit. That also
/// means unlocking a commitment itself is a hardware claim, not one made here.
@MainActor
final class UnlockCodeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        declineAnyAuthorizationPrompt(timeout: 1)
    }

    /// Set, refused on a wrong current code, then removed with the right one.
    ///
    /// One test because each step is only evidence beside the one before it: a
    /// removal that works proves nothing unless a wrong code was refused first.
    func testTheCodeIsSetRefusesAWrongCodeAndRemovesWithTheRightOne() throws {
        let app = try launchOnTargets()

        let link = app.buttons["settings"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "No way to Settings.\n\(app.debugDescription)")
        link.tap()

        guard app.staticTexts["No unlock code is set."].waitForExistence(timeout: 5) else {
            throw XCTSkip("A code is already set on this simulator, and only its holder can remove it.")
        }

        app.buttons["Set code"].tap()
        tap("2468", in: app)
        tap("2468", in: app)

        XCTAssertTrue(
            app.staticTexts["An unlock code is set."].waitForExistence(timeout: 5),
            "Setting a code did not take.\n\(app.debugDescription)")

        app.buttons["Remove code"].tap()
        tap("0000", in: app)

        XCTAssertTrue(
            app.staticTexts["That is not the current code."].waitForExistence(timeout: 5),
            "A wrong current code was not refused.\n\(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["An unlock code is set."].exists)

        app.buttons["Remove code"].tap()
        tap("2468", in: app)

        XCTAssertTrue(
            app.staticTexts["No unlock code is set."].waitForExistence(timeout: 5),
            "The right current code did not remove it.\n\(app.debugDescription)")
    }

    /// One press per digit on the pad, each waited for, because the pad's
    /// keys are the only buttons on the screen labelled with a single digit.
    private func tap(_ digits: String, in app: XCUIApplication) {
        for digit in digits {
            let key = app.buttons[String(digit)]
            XCTAssertTrue(key.waitForExistence(timeout: 5), "No \(digit) key.\n\(app.debugDescription)")
            key.tap()
        }
    }
}
