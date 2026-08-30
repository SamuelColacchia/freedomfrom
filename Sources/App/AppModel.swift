import FamilyControls
import Foundation
import FreedomFromKit
import FreedomFromPlatform
import Observation

/// Everything the app knows, which is the record plus whatever this launch has
/// been able to observe about the device.
///
/// It has no voice for things going wrong (ADR 0005). A revoked authorization,
/// a reinstall, a degraded commitment and a late release all pass through here
/// in silence; what replaces the message is a countdown that states real
/// coverage, and a history row written afterwards.
@MainActor
@Observable
final class AppModel {
    enum Destination {
        case firstRun
        case targets
        case countdown
        case ended
    }

    private(set) var record = Record.empty
    private(set) var coverage = Coverage(resolved: 0, named: 0)

    /// The apps chosen in *this* session, and nowhere else. Never restored from
    /// the record: hardware check S3 came back red, so a stored selection does
    /// not hand back to the picker with its apps checked (ADR 0008, as amended).
    var selection = FamilyActivitySelection()

    /// How many apps that selection names, minted the same way commit mints
    /// them, so the number on screen is the number that will be enforced.
    ///
    /// Held rather than computed because every read of it encodes a token, and
    /// the two screens that show it redraw far more often than the picker
    /// closes. It moves only where `selection` does, and both places it moves
    /// are in this file.
    private(set) var chosenTargetCount = 0

    /// Whether the record has been read yet. Until it has, the root draws the
    /// launch background and nothing else: routing on an empty record would
    /// show first run to somebody mid-commitment.
    private(set) var hasReadRecord = false

    private let log = Log(.app)
    private let marker = InstallMarker()
    private var reconciler: Reconciler { Reconciler(log: log) }

    var destination: Destination {
        if record.active != nil { return .countdown }
        if !record.hasSeenFirstRun { return .firstRun }
        if record.endedScreenPending { return .ended }
        return .targets
    }

    var draft: Draft { record.draft }

    /// The count the countdown states: app targets that still resolve, plus
    /// typed domains, which always do. This is the substitute for every message
    /// the app refuses to show, so it counts what is actually enforced rather
    /// than what was named at commit.
    var statedCoverage: Coverage {
        let domains = record.active?.domains.count ?? 0
        return Coverage(resolved: coverage.resolved + domains, named: coverage.named + domains)
    }

    /// The two halves of a target set live apart now — apps in this session,
    /// domains in the draft — so the question of whether there is anything to
    /// commit to is asked here, where both are in view.
    var canCommit: Bool { chosenTargetCount > 0 || !record.draft.domains.isEmpty }

    // MARK: - Launch and foreground

    func onLaunch() async {
        log.woke("launch")
        #if HARDWARE_PASS
            // Announced every launch so no capture can be mistaken for a clean
            // run. A build carrying a release control is not the product.
            log.woke("hardware-pass build")
        #endif
        // Read before placing: an absent marker beside a running commitment is
        // the only evidence that this install is not the one that committed.
        let reinstalled = !marker.isPresent
        marker.place()

        // The read first and alone, so the right screen is on the glass before
        // anything talks to a daemon.
        let reconciler = reconciler
        if let stored = await Task.detached(priority: .userInitiated, operation: {
            reconciler.peek()
        }).value {
            record = stored
        }
        hasReadRecord = true

        await reconcile(reinstalled: reinstalled)
    }

    func onForeground() async {
        log.woke("foreground")
        await reconcile(reinstalled: false)
    }

    /// Observes what this launch can, then runs the shared reconciliation.
    ///
    /// Authorization is re-requested on every launch while a commitment runs,
    /// so a moment of weakness does not end a month of commitment. Declining
    /// the re-request is accepted and not pursued.
    private func reconcile(reinstalled: Bool) async {
        let authorized = Self.isAuthorized
        log.authorization(String(describing: AuthorizationCenter.shared.authorizationStatus))

        apply(await offMainActor(brokenObserved: reinstalled || !authorized))

        guard record.active != nil, !Self.isAuthorized else { return }
        await requestAuthorization()
        if Self.isAuthorized { apply(await offMainActor()) }
    }

    /// A reconciliation touches the Keychain, five `ManagedSettings` writes —
    /// one of them device-wide — a shared-container file, and two
    /// `DeviceActivityCenter` calls. None of those types is `@MainActor`, and
    /// on a device every one of them is a daemon round-trip.
    ///
    /// Run on the main actor they blocked the first frame for about a minute
    /// while a commitment was live, which looked exactly like an app that takes
    /// a minute to launch. The work is unchanged; only the thread is.
    private func offMainActor(brokenObserved: Bool = false) async -> Reconciler.State {
        let reconciler = reconciler
        return await Task.detached(priority: .userInitiated) {
            reconciler.run(brokenObserved: brokenObserved)
        }.value
    }

    private func apply(_ state: Reconciler.State) {
        switch state {
        case .unreadable:
            // Nothing to say and nothing safe to assume. The next foreground
            // tries again; until then the app holds what it last knew.
            return
        // Nothing here touches `selection`. A stored one does not come back
        // checked (hardware check S3), so restoring it would put a count on
        // Targets that the picker then contradicts. Reconciliation moves the
        // record; the picker is the only thing that moves the selection.
        case .idle(let record), .released(let record):
            self.record = record
            coverage = Coverage(resolved: 0, named: 0)
        case .running(let record, let coverage):
            self.record = record
            self.coverage = coverage
        }
    }

    private static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The OS owns this prompt and its refusal. There is no eighth kind
            // of screen for an anomaly, so the app asks again next launch.
            log.authorization("request refused")
        }
        log.authorization(String(describing: AuthorizationCenter.shared.authorizationStatus))
    }

    // MARK: - First run

    func beginFromFirstRun() async {
        record.hasSeenFirstRun = true
        persist()
        await requestAuthorization()
    }

    // MARK: - The picked apps, and the draft

    /// The picker has closed. Nothing is written: apps are not part of the
    /// draft, so this changes only what this session is holding.
    func selectionChanged() {
        chosenTargetCount = TargetHandles.mint(from: selection).count
    }

    func addDomain(_ typed: String) {
        record.draft.domains = WebDomain.add(typed, to: record.draft.domains)
        persist()
    }

    func removeDomain(_ domain: WebDomain) {
        record.draft.domains.removeAll { $0 == domain }
        persist()
    }

    func chooseLength(_ length: CommitmentLength) {
        record.draft.length = length
    }

    /// The draft is written when a domain is committed with return, and when
    /// the app backgrounds — so a finished domain always survives an
    /// interruption and a half-typed one never does (ADR 0008).
    ///
    /// The picker returning used to write too. It no longer has anything to
    /// write: apps left the draft when hardware check S3 came back red.
    func persist() {
        // Fire and forget. A draft write is the user's own edit landing, so
        // nothing waits on it and nothing reads its result — and it is still a
        // Keychain round-trip, which does not belong on the thread drawing the
        // list it just changed.
        let snapshot = record
        let reconciler = reconciler
        Task.detached(priority: .utility) { reconciler.write(snapshot) }
    }

    // MARK: - Commit

    func commit(_ length: CommitmentLength) async {
        let now = Date()
        let handles = TargetHandles.mint(from: selection)
        let domains = record.draft.domains
        guard !handles.isEmpty || !domains.isEmpty else { return }

        // Enforcement is a precondition for a commitment existing, and
        // authorization is the only part of it the app can read back. Without
        // it nothing is written and the app re-requests rather than reporting
        // an error (ADR 0005).
        guard Self.isAuthorized else {
            await requestAuthorization()
            return
        }

        var committed = record
        committed.draft.length = length
        committed.begin(
            Commitment(
                startedAt: now,
                deadline: length.deadline(from: now),
                encodedSelection: TargetHandles.encode(selection),
                namedHandles: handles,
                domains: domains
            ))

        // The write *is* the commitment. Once the record holds it the deadline
        // is real, absolute, and outlives the app being deleted — so the screen
        // can change here, on a `SecItem` write measured in milliseconds.
        // Bound as a constant because the closure below is `@Sendable`, and a
        // `var` still being mutated in this scope cannot cross into one.
        let toWrite = committed
        let reconciler = reconciler
        let written = await Task.detached(priority: .userInitiated) { () -> Bool in
            reconciler.write(toWrite)
        }.value
        guard written else { return }

        record = toWrite
        // Nothing is enforced yet, and the countdown states coverage rather
        // than what was named (ADR 0005). Zero is the true answer for the
        // moment it is on screen, and it corrects upward when the shield lands.
        coverage = Coverage(resolved: 0, named: 0)

        // Enforcement follows, behind a countdown that is already drawn. Waiting
        // for it before routing is what put a hold that *had* fired behind a
        // screen that had not moved: five `ManagedSettings` writes, a shared
        // file, and two `DeviceActivityCenter` calls, which on a device is not
        // milliseconds. The shield coming up minutes after the bar filled was
        // this, and it read as the button being dead.
        apply(await offMainActor())
    }

    // MARK: - Afterwards

    func acknowledgeEnded() {
        record.endedScreenPending = false
        persist()
    }

    #if HARDWARE_PASS
        /// Brings the deadline forward to now, so the ordinary release path
        /// runs. Compiled only into a build that asked for it.
        ///
        /// The product has no such action anywhere, by design (ADR 0001). The
        /// hardware pass needs one anyway: it commits and observes fifteen
        /// times, and the only other way out is the Screen Time revoke — which
        /// *is* check X1, and taking it repeatedly would contaminate every
        /// observation of the clean run it is supposed to be separate from.
        ///
        /// It shortens the deadline rather than releasing directly, so what
        /// gets exercised is the same reconciliation the Monitor and the shield
        /// run. A release reached by a different path would prove nothing about
        /// the one that ships.
        func releaseForHardwarePass() async {
            guard let active = record.active else { return }

            var shortened = record
            shortened.begin(
                Commitment(
                    id: active.id,
                    startedAt: active.startedAt,
                    deadline: Date(),
                    encodedSelection: active.encodedSelection,
                    namedHandles: active.namedHandles,
                    domains: active.domains,
                    isDegraded: active.isDegraded,
                    isBroken: active.isBroken
                ))

            // Named in the log so a capture shows the run was not clean.
            log.storeMutation("hardware-pass release", landed: true)

            let reconciler = reconciler
            apply(
                await Task.detached(priority: .userInitiated) {
                    reconciler.write(shortened)
                    return reconciler.run()
                }.value)
        }
    #endif

    func cleanSlate() {
        record.cleanSlate()
        selection = FamilyActivitySelection()
        chosenTargetCount = 0
        persist()
    }
}
