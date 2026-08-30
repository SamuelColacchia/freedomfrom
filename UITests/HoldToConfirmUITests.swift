import XCTest

/// The hold is the app's one irreversible action, and the only part of the
/// product a compiler cannot check and a kit test cannot reach.
///
/// It has shipped broken twice: `onLongPressGesture` reports the press
/// beginning, the bar fills the whole way, and the completion never arrives
/// (FB15711941). Both times a green build and a green kit suite said nothing was
/// wrong, because neither of them presses anything. This does.
///
/// **What it can and cannot prove.** It proves the hold fires — that a press
/// held to its full duration reaches the action, and that one released early
/// does not. It does not reproduce FB15711941 itself: a synthesised press is
/// perfectly still, and the recogniser that fails under a real thumb succeeds
/// under this one. The phone remains the only place that particular bug shows.
@MainActor
final class HoldToConfirmUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // The prompt outlives the app, so a run that leaves one standing hands the
    // next test a modal it did not raise. Async because the synchronous
    // `tearDown` is nonisolated and every XCUITest query is main-actor bound.
    override func tearDown() async throws {
        declineAnyAuthorizationPrompt(timeout: 1)
    }

    /// A press held to its full duration reaches the action.
    ///
    /// Committing needs Family Controls authorization, which this simulator has
    /// not granted — so `commit()` asks for it and returns. That request is the
    /// proof: the Screen Time prompt is raised by the app, only ever from an
    /// action, and there is no path to it from a hold that never fired.
    func testTheCommitHoldFires() throws {
        let app = XCUIApplication()
        app.launch()
        declineAnyAuthorizationPrompt(timeout: 2)

        try reachCommitScreen(in: app)
        XCTAssertFalse(
            authorizationPrompt.exists,
            "A prompt was already standing before the press, so it proves nothing.")

        // Longer than the shortest hold the app asks for, which is the 1.5s of a
        // fifteen-minute commitment — the length this screen preselects.
        holdButton(in: app).press(forDuration: 3.0)

        XCTAssertTrue(
            authorizationPrompt.waitForExistence(timeout: 8),
            """
            The hold ran its full duration and the action never fired. This is \
            the shape of FB15711941: the bar fills and nothing happens.
            Screen after the hold:
            \(app.debugDescription)
            """)
    }

    /// Releasing early does nothing, which is the other half of the contract:
    /// the hold has to be a hold, not a tap with a slow animation in front of it.
    func testAReleasedHoldDoesNothing() throws {
        let app = XCUIApplication()
        app.launch()
        declineAnyAuthorizationPrompt(timeout: 2)

        try reachCommitScreen(in: app)

        holdButton(in: app).press(forDuration: 0.4)

        XCTAssertFalse(
            authorizationPrompt.waitForExistence(timeout: 5),
            "A hold released well short of its duration committed anyway.")
    }

    // MARK: - Getting there

    private func holdButton(in app: XCUIApplication) -> XCUIElement {
        let hold = app.descendants(matching: .any)["hold"]
        XCTAssertTrue(
            hold.waitForExistence(timeout: 5),
            "No hold button on this screen.\n\(app.debugDescription)")
        return hold
    }

    /// First run if it is showing, then a domain, then Next. Written to tolerate
    /// a simulator whose Keychain already holds a record, because the record
    /// survives the app being deleted by design and no test can clear it.
    private func reachCommitScreen(in app: XCUIApplication) throws {
        let begin = app.buttons["Begin"]
        if begin.waitForExistence(timeout: 3) {
            begin.tap()
            declineAnyAuthorizationPrompt(timeout: 8)
        }

        let next = app.buttons["Next"]
        guard next.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                """
                Not on Targets, so this simulator is mid-commitment or in a state \
                no test can reset. Screen was:
                \(app.debugDescription)
                """)
        }

        // A domain typed by the earlier test in this run is still in the draft,
        // so Next is already live and the keyboard never has to appear.
        if !next.isEnabled {
            // A domain is enough to reach Commit and needs no picker, which is
            // the whole reason this runs without a person (ADR 0008 as amended:
            // apps are chosen per session, and the simulator has no picker).
            try type("example.com\n", intoFieldOf: app)
        }

        XCTAssertTrue(
            next.isEnabled, "Next stayed disabled after a domain.\n\(app.debugDescription)")
        next.tap()
    }

    /// Taps the field until the keyboard actually has it. The first tap after a
    /// launch lands before the field is ready often enough to fail a run alone.
    private func type(_ text: String, intoFieldOf app: XCUIApplication) throws {
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

    // MARK: - The prompt

    private var authorizationPrompt: XCUIElement {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    }

    /// Declined rather than granted, deliberately. Granting would let the next
    /// hold commit for real, and a simulator holding a commitment sends every
    /// later run to the Countdown, where there is no hold to press.
    private func declineAnyAuthorizationPrompt(timeout: TimeInterval) {
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
}
