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

    private(set) var record: Record
    private(set) var coverage = Coverage(resolved: 0, named: 0)
    var selection = FamilyActivitySelection()

    init(record: Record = .empty) {
        self.record = record
    }

    private let log = Log(.app)
    private let store = KeychainRecordStore()
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

    var canCommit: Bool { !record.draft.isEmpty }

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

        apply(
            reconciler.run { record in
                guard record.active != nil, reinstalled || !authorized else { return }
                if record.markBroken() { self.log.marked(.broken) }
            })

        guard record.active != nil, !Self.isAuthorized else { return }
        await requestAuthorization()
        if Self.isAuthorized { apply(reconciler.run()) }
    }

    private func apply(_ state: Reconciler.State) {
        switch state {
        case .unreadable:
            // Nothing to say and nothing safe to assume. The next foreground
            // tries again; until then the app holds what it last knew.
            return
        case .idle(let record), .released(let record):
            self.record = record
            coverage = Coverage(resolved: 0, named: 0)
        case .running(let record, let coverage):
            self.record = record
            self.coverage = coverage
            selection = TargetHandles.decode(record.active?.encodedSelection) ?? selection
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

    // MARK: - The draft

    func selectionChanged() {
        record.draft.encodedSelection = TargetHandles.encode(selection)
        record.draft.namedTargetCount = TargetHandles.mint(from: selection).count
        persist()
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

    /// The draft is written when the picker returns, when a domain is committed
    /// with return, and when the app backgrounds — so a finished domain always
    /// survives an interruption and a half-typed one never does (ADR 0008).
    func persist() {
        reconciler.write(record)
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

        do {
            try store.write(committed)
            log.recordWritten()
        } catch {
            log.recordWriteFailed(status: Reconciler.osStatus(error))
            return
        }

        // The same reconciliation every launch runs: it applies the shield and
        // the filter, mirrors the deadline, and registers the first window.
        apply(reconciler.run(now: now))
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
            try? store.write(shortened)
            apply(reconciler.run())
        }
    #endif

    func cleanSlate() {
        record.cleanSlate()
        selection = FamilyActivitySelection()
        persist()
    }
}
