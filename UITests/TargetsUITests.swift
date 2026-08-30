import XCTest

/// The two screens a person meets first, driven rather than described.
///
/// Every claim issue #26 makes about them is a thing done with a finger: Next
/// goes live on a typed domain, a refused one leaves the screen exactly as it
/// was, a finished domain outlives an interruption and a half-typed one does
/// not. None of that is reachable from a compiler or from the kit's suite, and
/// the only evidence any of it ever had was a gallery of renders that was
/// thrown away — taken before the draft lost its apps (#38) and before the
/// count learned to name a category (#44), so it no longer describes this app.
///
/// **What this cannot reach.** The picker is a system sheet with nothing behind
/// it on a simulator that has declined authorization, so "the picker is a sheet"
/// stays a hardware claim. So does the history line, whose absence is a fact
/// about a record no test can read. Both are named here rather than quietly
/// dropped.
@MainActor
final class TargetsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // The prompt outlives the app, so a run that leaves one standing hands the
    // next test a modal it did not raise.
    override func tearDown() async throws {
        declineAnyAuthorizationPrompt(timeout: 1)
    }

    /// First run is shown once, ever, and Targets is what stands behind it.
    ///
    /// The record survives the app being deleted (ADR 0002), so a simulator that
    /// has already seen first run cannot be made to show it again — which is the
    /// claim, and is why an absent "Begin" is evidence here rather than a reason
    /// to skip. Whichever branch this takes, the assertion after the relaunch is
    /// the same one.
    func testFirstRunIsShownOnceAndTargetsStandsBehindIt() throws {
        let app = try launchOnTargets()

        app.terminate()
        app.launch()
        declineAnyAuthorizationPrompt(timeout: 2)

        XCTAssertTrue(
            app.buttons["Next"].waitForExistence(timeout: 5),
            "Nothing is running, so the root is Targets.\n\(app.debugDescription)")
        XCTAssertFalse(
            app.buttons["Begin"].exists,
            """
            First run came back on a second launch. It is the only moment \
            informed consent happens and it is shown once, ever (ADR 0007).
            \(app.debugDescription)
            """)
    }

    /// Next is unreachable with nothing chosen, and one typed domain is enough.
    ///
    /// Both halves in one test because the second is only worth anything beside
    /// the first: a Next that was live all along proves nothing by being live
    /// after typing.
    func testNextIsUnreachableWithNothingChosenAndReachableWithOneDomain() throws {
        let app = try launchOnTargets()
        clearTypedDomains(in: app)

        let next = app.buttons["Next"]
        XCTAssertFalse(
            next.isEnabled,
            """
            Next was reachable with nothing chosen. The commit screen is not a \
            place you can arrive at with nothing to commit to (ADR 0005).
            \(app.debugDescription)
            """)

        try type("example.com\n", intoFieldOf: app)

        XCTAssertTrue(
            app.staticTexts["example.com"].waitForExistence(timeout: 3),
            "A typed domain is the one part of a target set the app reads back.")
        XCTAssertTrue(
            next.isEnabled,
            "One typed domain is enough to commit — no app need be picked.")
    }

    /// A refused domain changes nothing on screen and says nothing.
    ///
    /// `nodot` canonicalizes to a host with no dot, which cannot match anything,
    /// so the app drops it (ADR 0006). That refusal is a flow rule rather than
    /// an error, and the app has no voice for it — so the evidence is that the
    /// screen is identical afterwards and no alert was raised.
    func testARefusedDomainChangesNothingAndSaysNothing() throws {
        let app = try launchOnTargets()
        clearTypedDomains(in: app)

        try type("nodot\n", intoFieldOf: app)

        XCTAssertEqual(
            removeButtons(in: app).count, 0,
            "A refused entry put a row on the targets screen that blocks nothing.")
        XCTAssertFalse(
            app.staticTexts["nodot"].exists,
            "A refused entry is not displayed: displayed, stored and applied are the same string.")
        XCTAssertFalse(
            app.buttons["Next"].isEnabled,
            "A refused entry counted towards having something to commit to.")
        XCTAssertFalse(
            app.alerts.firstMatch.exists || authorizationPrompt.exists,
            "The app said something about a refusal. It has no voice for one (ADR 0003).")
    }

    /// A finished domain survives an interruption and a relaunch.
    ///
    /// This proves the domain is still there on the next launch, not which of
    /// the draft's two write triggers put it there — submitting writes it
    /// immediately, so backgrounding is exercised here rather than isolated. The
    /// discriminating half of ADR 0008's sentence is the test below.
    func testAFinishedDomainSurvivesBackgroundingAndARelaunch() throws {
        let app = try launchOnTargets()
        clearTypedDomains(in: app)
        try type("finished.example.com\n", intoFieldOf: app)
        XCTAssertTrue(app.staticTexts["finished.example.com"].waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(
            app.wait(for: .runningBackground, timeout: 5),
            "The app never backgrounded, so the write this is about never fired.")
        app.terminate()

        let relaunched = try launchOnTargets(app)

        XCTAssertTrue(
            relaunched.staticTexts["finished.example.com"].waitForExistence(timeout: 5),
            """
            A finished domain did not survive the interruption. The entrance is \
            untaxed for everything the app can read back (ADR 0008).
            \(relaunched.debugDescription)
            """)
        clearTypedDomains(in: relaunched)
    }

    /// A half-typed domain never survives one.
    ///
    /// The other half of ADR 0008's rule, and the half that discriminates: the
    /// draft is written on a submitted domain and on backgrounding, and text
    /// still sitting in the field is neither.
    func testAHalfTypedDomainDoesNotSurviveARelaunch() throws {
        let app = try launchOnTargets()
        clearTypedDomains(in: app)
        try type("half.example.com", intoFieldOf: app)

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.terminate()

        let relaunched = try launchOnTargets(app)

        XCTAssertFalse(
            relaunched.staticTexts["half.example.com"].exists,
            """
            Text left in the field became a target. Only a domain committed with \
            return is in the draft (ADR 0008).
            \(relaunched.debugDescription)
            """)
        XCTAssertEqual(removeButtons(in: relaunched).count, 0)
    }

    /// Removing a typed domain takes it off the screen, which is the only way a
    /// draft is emptied by hand: ADR 0008 rejected a clear action on Targets
    /// because the field and the picker already empty it.
    func testRemovingATypedDomainTakesItOffTheScreen() throws {
        let app = try launchOnTargets()
        clearTypedDomains(in: app)
        try type("removable.example.com\n", intoFieldOf: app)
        XCTAssertTrue(app.staticTexts["removable.example.com"].waitForExistence(timeout: 3))

        removeButtons(in: app).element(boundBy: 0).tap()

        XCTAssertFalse(
            app.staticTexts["removable.example.com"].exists,
            "A removed domain stayed on screen.\n\(app.debugDescription)")
        XCTAssertFalse(
            app.buttons["Next"].isEnabled,
            "Removing the last domain left Next reachable with nothing chosen.")
    }
}
