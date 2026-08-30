import DeviceActivity
import FamilyControls
import Foundation
import FreedomFromKit
import FreedomFromPlatform
import ManagedSettings

/// Everything the skeleton needs to exercise the whole chain once.
///
/// The interesting behaviour is in what it *logs*, not what it shows: the
/// hardware checks this skeleton exists to run (E1, S1, S2, S3) are all read
/// out of the unified log rather than off the screen (ADR 0009).
@MainActor
@Observable
final class SkeletonModel {
    private let log = Log(.app)
    private let store = KeychainRecordStore()

    var selection = FamilyActivitySelection()
    var authorization = "unknown"
    var status = "—"
    var deadline: Date?
    var coverage: Coverage?

    // MARK: - Launch

    /// Every launch reconciles. The app is one of the three places that
    /// compares now against the stored absolute deadline (ADR 0004).
    func onLaunch() async {
        log.woke("launch")
        await refreshAuthorization()

        let record: Record?
        do {
            record = try store.read()
            log.recordRead(found: record != nil, hasActiveCommitment: record?.active != nil)
        } catch {
            log.recordUnreadable(status: Self.osStatus(error))
            status = "record unreadable"
            return
        }

        guard var record, let active = record.active else {
            status = "nothing running"
            return
        }

        deadline = active.deadline
        log.deadline(active.deadline)

        if Date() >= active.deadline {
            release(record: &record, deadline: active.deadline)
            return
        }

        // Restore the selection so the picker can be checked against it (S3),
        // then state coverage as it is now rather than as it was at commit.
        if let encoded = active.encodedSelection,
            let restored = try? JSONDecoder().decode(FamilyActivitySelection.self, from: encoded)
        {
            selection = restored
        }
        let live = Coverage(resolved: handles(of: selection).count, named: active.namedHandles.count)
        coverage = live
        log.coverage(live)
        status = "running"
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The OS owns this prompt, so the app re-requests rather than
            // reporting an error (ADR 0005).
            status = "authorization refused"
        }
        await refreshAuthorization()
    }

    private func refreshAuthorization() async {
        let state = String(describing: AuthorizationCenter.shared.authorizationStatus)
        authorization = state
        log.authorization(state)
    }

    // MARK: - Commit

    /// A short commitment, enough to prove the chain end to end. The real
    /// durations, the hold, and the walk-forward step are later work items.
    func commit(minutes: Int = 15) {
        let now = Date()
        let deadline = now.addingTimeInterval(TimeInterval(minutes * 60))
        let named = handles(of: selection)

        guard !named.isEmpty else {
            status = "nothing selected"
            return
        }

        // Enforcement is a precondition for a commitment existing: if it does
        // not apply, nothing is written and there is nothing to release,
        // reconcile, or file in the history (ADR 0005, ADR 0006).
        let applied = applyEnforcement()
        guard applied else {
            status = "enforcement did not apply"
            return
        }

        var record = (try? store.read()) ?? .empty
        record.active = Commitment(
            startedAt: now,
            deadline: deadline,
            encodedSelection: try? JSONEncoder().encode(selection),
            namedHandles: named,
            domains: []
        )
        record.hasSeenFirstRun = true

        do {
            try store.write(record)
            log.recordWritten()
        } catch {
            log.recordWriteFailed(status: Self.osStatus(error))
            Enforcement.releaseEverything()
            status = "record write failed"
            return
        }

        log.deadline(deadline)
        let live = Coverage(resolved: named.count, named: named.count)
        coverage = live
        log.coverage(live)
        registerWindow(deadline: deadline)

        self.deadline = deadline
        status = "running"
    }

    private func applyEnforcement() -> Bool {
        let store = Enforcement.store
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        log.storeMutation("shield", landed: true)

        // Collateral, not the product: these failing changes nothing, and there
        // is no read-back of effective state to check them with (ADR 0005).
        store.application.denyAppRemoval = true
        store.dateAndTime.requireAutomaticDateAndTime = true
        log.storeMutation("restrictions", landed: true)
        return true
    }

    private func registerWindow(deadline: Date) {
        guard let window = Enforcement.skeletonWindow(deadline: deadline) else { return }
        do {
            try DeviceActivityCenter().startMonitoring(
                .commitment, during: Enforcement.schedule(for: window))
            log.windowRegistered(window)
        } catch {
            log.windowRegistrationFailed(String(describing: error))
        }
    }

    // MARK: - Release

    /// Only the deadline releases a commitment. This button exists so the
    /// skeleton can be re-run without waiting fifteen minutes; v1 has no such
    /// action anywhere, by design (ADR 0001).
    func forceReleaseForSkeletonOnly() {
        guard var record = (try? store.read()), let active = record.active else {
            Enforcement.releaseEverything()
            status = "nothing running"
            return
        }
        release(record: &record, deadline: active.deadline)
    }

    private func release(record: inout Record, deadline: Date) {
        Enforcement.releaseEverything()
        log.storeMutation("release", landed: true)
        log.released(lateBy: max(0, Date().timeIntervalSince(deadline)))

        record.active = nil
        record.endedScreenPending = true
        try? store.write(record)

        self.deadline = nil
        coverage = nil
        status = "ended"
    }

    // MARK: - Handles

    /// The app mints a handle per token as the base64 of its encoding. A token
    /// that churns yields a different handle, which is the only signal that
    /// anything is unresolvable — and whether it works at all is check X4.
    private func handles(of selection: FamilyActivitySelection) -> [TargetHandle] {
        let encoder = JSONEncoder()
        let apps = selection.applicationTokens.compactMap { token -> TargetHandle? in
            guard let data = try? encoder.encode(token) else { return nil }
            return TargetHandle(data.base64EncodedString())
        }
        let categories = selection.categoryTokens.compactMap { token -> TargetHandle? in
            guard let data = try? encoder.encode(token) else { return nil }
            return TargetHandle(data.base64EncodedString())
        }
        return (apps + categories).sorted { $0.value < $1.value }
    }

    private static func osStatus(_ error: Error) -> Int32 {
        if case KeychainRecordStore.Failure.keychain(let status) = error { return status }
        return -1
    }
}
