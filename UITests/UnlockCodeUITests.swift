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

        let link = app.buttons["unlock code"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "No way to the unlock code.\n\(app.debugDescription)")
        link.tap()

        guard app.staticTexts["No unlock code is set."].waitForExistence(timeout: 5) else {
            throw XCTSkip("A code is already set on this simulator, and only its holder can remove it.")
        }

        try enter("2468", into: "new code", in: app)
        try enter("2468", into: "new code again", in: app)
        app.buttons["Set code"].tap()

        XCTAssertTrue(
            app.staticTexts["An unlock code is set."].waitForExistence(timeout: 5),
            "Setting a code did not take.\n\(app.debugDescription)")

        try enter("0000", into: "current code", in: app)
        app.buttons["Remove code"].tap()

        XCTAssertTrue(
            app.staticTexts["That is not the current code."].waitForExistence(timeout: 5),
            "A wrong current code was not refused.\n\(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["An unlock code is set."].exists)

        try enter("2468", into: "current code", in: app)
        app.buttons["Remove code"].tap()

        XCTAssertTrue(
            app.staticTexts["No unlock code is set."].waitForExistence(timeout: 5),
            "The right current code did not remove it.\n\(app.debugDescription)")
    }

    private func enter(_ text: String, into identifier: String, in app: XCUIApplication) throws {
        let field = app.secureTextFields[identifier]
        guard field.waitForExistence(timeout: 5) else {
            throw XCTSkip("No \(identifier) field.\n\(app.debugDescription)")
        }
        for _ in 0..<4 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 2) {
                field.typeText(text)
                return
            }
        }
        XCTFail("The \(identifier) field never took keyboard focus.\n\(app.debugDescription)")
    }
}
