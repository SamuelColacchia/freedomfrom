import Foundation

extension Outcome {
    /// Broken wins; else degraded; else completed. A commitment nobody was
    /// running to witness reads completed, because the app holds no evidence
    /// otherwise and must not invent any (ADR 0005).
    public init(isBroken: Bool, isDegraded: Bool) {
        if isBroken {
            self = .broken
        } else if isDegraded {
            self = .completedDegraded
        } else {
            self = .completed
        }
    }
}

extension ClosedCommitment {
    init(_ commitment: Commitment, outcome: Outcome) {
        self.init(
            startedAt: commitment.startedAt,
            deadline: commitment.deadline,
            namedTargetCount: commitment.namedHandles.count,
            domains: commitment.domains,
            outcome: outcome
        )
    }
}

extension Record {
    /// Unique web domains a device filters across every store an app owns.
    /// One over and iOS silently filters nothing at all (#80), so a
    /// commitment that would cross it is refused before the hold.
    public static let domainBudget = 50

    /// Starts a commitment beside any already running. The draft is untouched:
    /// committing consumes nothing, so the same targets and length are still
    /// there afterwards (ADR 0008).
    public mutating func begin(_ commitment: Commitment) {
        commitments.append(commitment)
    }

    /// Every typed domain held right now, once each, in the order first named.
    public var heldDomains: [WebDomain] {
        var seen = Set<WebDomain>()
        return commitments.flatMap(\.domains).filter { seen.insert($0).inserted }
    }

    /// Whether adding these domains to what is already held would cross the
    /// filter's budget.
    public func exceedsDomainBudget(adding domains: [WebDomain]) -> Bool {
        Set(heldDomains).union(domains).count > Self.domainBudget
    }

    /// The nearest deadline, which is the one the watchdog walks toward.
    public var earliestDeadline: Date? { commitments.map(\.deadline).min() }

    /// The furthest deadline. Nothing is released wholesale before it.
    public var latestDeadline: Date? { commitments.map(\.deadline).max() }

    /// Files every commitment whose deadline has passed and returns them,
    /// leaving "Ended." pending if any went. The rest keep running.
    ///
    /// This is the record half of a release; lifting the enforcement is the
    /// caller's, because the kit may not name a Screen Time type. A release can
    /// arrive late and never early, so `now` is recorded nowhere: the deadline
    /// is what the history states.
    @discardableResult
    public mutating func releaseDue(at now: Date) -> [Commitment] {
        let due = commitments.filter { Reconciliation.shouldRelease(deadline: $0.deadline, now: now) }
        guard !due.isEmpty else { return [] }

        for commitment in due {
            history.append(
                ClosedCommitment(
                    commitment,
                    outcome: Outcome(isBroken: commitment.isBroken, isDegraded: commitment.isDegraded)))
        }
        commitments.removeAll { due.map(\.id).contains($0.id) }
        endedScreenPending = true
        return due
    }

    /// Ends one commitment before its deadline, if `code` is the unlock code,
    /// and files it as unlocked. The others are untouched (ADR 0012).
    ///
    /// No "Ended." follows: the person is in the app, and did it.
    @discardableResult
    public mutating func unlock(_ id: UUID, code: String) -> Bool {
        guard let unlockCode, unlockCode.matches(code),
            let index = commitments.firstIndex(where: { $0.id == id })
        else { return false }

        history.append(ClosedCommitment(commitments.remove(at: index), outcome: .unlocked))
        return true
    }

    /// Sets the unlock code, or replaces it when `current` is the one set.
    /// Refused while anything runs: a code changeable mid-commitment would
    /// unlock nothing that its owner could not unlock alone.
    @discardableResult
    public mutating func setUnlockCode(_ new: String, current: String? = nil) -> Bool {
        guard commitments.isEmpty, holdsOrMatches(current),
            let made = UnlockCode.make(new)
        else { return false }
        unlockCode = made
        return true
    }

    /// Removes the unlock code, under the same rules as changing it.
    @discardableResult
    public mutating func removeUnlockCode(current: String) -> Bool {
        guard commitments.isEmpty, unlockCode != nil, holdsOrMatches(current) else { return false }
        unlockCode = nil
        return true
    }

    private func holdsOrMatches(_ current: String?) -> Bool {
        guard let unlockCode else { return true }
        return current.map(unlockCode.matches) ?? false
    }

    /// Marks every running commitment broken, and reports whether any was
    /// marked for the first time. An authorization loss reaches all of them at
    /// once (#73). A break marks a commitment; it does not end one, and it is
    /// recorded once and never re-marked (ADR 0005) — which is what the return
    /// value exists for: the log line fires on the transition, not on every
    /// launch that observes the state.
    @discardableResult
    public mutating func markBroken() -> Bool {
        var marked = false
        for index in commitments.indices where !commitments[index].isBroken {
            commitments[index].isBroken = true
            marked = true
        }
        return marked
    }

    /// Applies a fresh coverage reading to one commitment, and reports whether
    /// it newly degraded it.
    ///
    /// Degraded never clears: a commitment whose handles all resolve again
    /// stays degraded, because the mark records how it ran rather than how it
    /// is running. The deadline is not a parameter here for the same reason —
    /// a lost target costs coverage, never duration.
    @discardableResult
    public mutating func apply(_ coverage: Coverage, to id: UUID) -> Bool {
        guard !coverage.isComplete,
            let index = commitments.firstIndex(where: { $0.id == id }),
            !commitments[index].isDegraded
        else { return false }
        commitments[index].isDegraded = true
        return true
    }
}
