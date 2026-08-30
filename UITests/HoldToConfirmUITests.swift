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
        let app = try launchOnTargets()

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

    /// Released the instant the bar looks full, which is what a person actually
    /// does — and what the 3-second press above never tests, because it hands
    /// the hold a second and a half of slack no thumb ever gives it.
    ///
    /// The screen preselects fifteen minutes, whose hold is 1.5s.
    func testAHoldReleasedTheMomentItFillsStillFires() throws {
        let app = try launchOnTargets()

        try reachCommitScreen(in: app)
        XCTAssertFalse(authorizationPrompt.exists)

        holdButton(in: app).press(forDuration: 1.5)

        XCTAssertTrue(
            authorizationPrompt.waitForExistence(timeout: 8),
            """
            Held for exactly the duration it asks for and nothing fired. The bar \
            reaches full before the clock does, so releasing on the fill cancels \
            the action — which is what a person sees as "it filled, then nothing".
            \(app.debugDescription)
            """)
    }

    /// Releasing early does nothing, which is the other half of the contract:
    /// the hold has to be a hold, not a tap with a slow animation in front of it.
    func testAReleasedHoldDoesNothing() throws {
        let app = try launchOnTargets()

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

    /// Targets, then a domain, then Next. `AppDriving` handles the launch and
    /// first run; what is left here is the one thing this file needs that the
    /// Targets tests do not — getting past Next with something to commit to.
    private func reachCommitScreen(in app: XCUIApplication) throws {
        let next = app.buttons["Next"]

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
}
