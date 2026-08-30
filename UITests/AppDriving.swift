import XCTest

/// The kit's `WebDomain.ceiling`, restated rather than imported: a UI test
/// bundle links the app it drives, not the app's packages.
private let webDomainCeiling = 50

/// Getting the app to the screen a test is about, shared by everything in this
/// bundle.
///
/// It exists because the simulator is not a clean slate and cannot be made one:
/// the Keychain record survives the app being deleted by design (ADR 0002), so
/// every launch inherits whatever the last run left — a draft, a seen first run,
/// possibly a commitment. Each helper here therefore states what it found rather
/// than assuming, and skips rather than fails when the simulator is in a state
/// no test can reset.
@MainActor
extension XCTestCase {
    /// The Screen Time prompt. SpringBoard owns it, not the app, so it is not
    /// reachable through `XCUIApplication()`.
    var authorizationPrompt: XCUIElement {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    }

    /// Declined rather than granted, deliberately. Granting would let a hold
    /// commit for real, and a simulator holding a commitment sends every later
    /// run to the Countdown, where none of these screens exist.
    func declineAnyAuthorizationPrompt(timeout: TimeInterval) {
        let alert = authorizationPrompt
        guard alert.waitForExistence(timeout: timeout) else { return }

        let buttons = alert.buttons.allElementsBoundByIndex
        let refusal = buttons.first {
            let label = $0.label.lowercased()
            return label.contains("don't") || label.contains("not now")
                || label.contains("cancel")
        }
        (refusal ?? buttons.last)?.tap()
    }

    /// Launches, walks first run if it is standing, and hands back an app
    /// sitting on Targets.
    ///
    /// Skips when Targets is not where it lands: that means a commitment is
    /// running on this simulator, and nothing in a test can end one — which is
    /// the whole point of the product (ADR 0001).
    @discardableResult
    func launchOnTargets(_ app: XCUIApplication = XCUIApplication()) throws -> XCUIApplication {
        app.launch()
        declineAnyAuthorizationPrompt(timeout: 2)

        let begin = app.buttons["Begin"]
        if begin.waitForExistence(timeout: 3) {
            begin.tap()
            declineAnyAuthorizationPrompt(timeout: 8)
        }

        guard app.buttons["Next"].waitForExistence(timeout: 5) else {
            throw XCTSkip(
                """
                Not on Targets, so this simulator is mid-commitment or in a state \
                no test can reset. Screen was:
                \(app.debugDescription)
                """)
        }
        return app
    }

    /// Taps the field until the keyboard actually has it. The first tap after a
    /// launch lands before the field is ready often enough to fail a run alone.
    ///
    /// A trailing newline submits, which is the only way a domain reaches the
    /// draft — so passing one and leaving one off is the difference between a
    /// finished domain and a half-typed one (ADR 0008).
    func type(_ text: String, intoFieldOf app: XCUIApplication) throws {
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 5) else {
            throw XCTSkip("No domain field on Targets.\n\(app.debugDescription)")
        }

        for _ in 0..<4 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 2) {
                field.typeText(text)
                return
            }
        }
        XCTFail("The domain field never took keyboard focus.\n\(app.debugDescription)")
    }

    /// Every typed domain currently on Targets, as the rows a person removes.
    ///
    /// Matched on the label rather than an identifier because the app gives its
    /// controls no identifiers beyond the hold, and a row's remove is the only
    /// button on the screen wearing this word.
    func removeButtons(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "remove"))
    }

    /// Empties the draft through the app's own controls, so a test can start
    /// from nothing chosen without reaching into a store it is not allowed to
    /// touch.
    ///
    /// Bounded by the fifty-domain ceiling (ADR 0006): a remove that stopped
    /// removing would otherwise spin here rather than fail.
    func clearTypedDomains(in app: XCUIApplication) {
        let removes = removeButtons(in: app)
        for _ in 0...webDomainCeiling where removes.count > 0 {
            removes.element(boundBy: 0).tap()
        }
        XCTAssertEqual(
            removes.count, 0,
            "Typed domains would not come off the screen.\n\(app.debugDescription)")
    }
}
