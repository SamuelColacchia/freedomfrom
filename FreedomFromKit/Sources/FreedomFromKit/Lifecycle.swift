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

extension Record {
    /// Starts a commitment. The draft is untouched: committing consumes
    /// nothing, so the same targets and length are still there afterwards
    /// (ADR 0008).
    public mutating func begin(_ commitment: Commitment) {
        active = commitment
    }

    /// Files the running commitment in the history and leaves "Ended." pending.
    ///
    /// This is the record half of a release; lifting the enforcement is the
    /// caller's, because the kit may not name a Screen Time type. A release can
    /// arrive late and never early, so `now` is recorded nowhere: the deadline
    /// is what the history states.
    public mutating func release(at now: Date) {
        guard let active else { return }

        history.append(
            ClosedCommitment(
                startedAt: active.startedAt,
                deadline: active.deadline,
                namedTargetCount: active.namedHandles.count,
                domains: active.domains,
                outcome: Outcome(isBroken: active.isBroken, isDegraded: active.isDegraded)
            ))
        self.active = nil
        endedScreenPending = true
    }

    /// Marks the running commitment broken, and reports whether this was the
    /// first time. A break marks a commitment; it does not end one, and it is
    /// recorded once and never re-marked (ADR 0005) — which is what the return
    /// value exists for: the log line fires on the transition, not on every
    /// launch that observes the state.
    @discardableResult
    public mutating func markBroken() -> Bool {
        guard var active, !active.isBroken else { return false }
        active.isBroken = true
        self.active = active
        return true
    }

    /// Applies a fresh coverage reading, and reports whether it newly degraded
    /// the commitment.
    ///
    /// Degraded never clears: a commitment whose handles all resolve again
    /// stays degraded, because the mark records how it ran rather than how it
    /// is running. The deadline is not a parameter here for the same reason —
    /// a lost target costs coverage, never duration.
    @discardableResult
    public mutating func apply(_ coverage: Coverage) -> Bool {
        guard var active, !coverage.isComplete, !active.isDegraded else { return false }
        active.isDegraded = true
        self.active = active
        return true
    }
}
