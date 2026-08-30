# A wordless v1 flow

v1's seven screens were prototyped as three whole personalities — a signed contract, a wordless monastic room, and a technical instrument — and **The Quiet Room won outright**. The rule it embodies: **freedomfrom does not argue. Every screen is one statement and one action, and the only ceremony in the app is the hold that commits you.** What little it says is therefore load-bearing; nothing on any screen is decorative.

The prototype is the primary source, on branch [`prototype/v1-commit-flow`](https://github.com/SamuelColacchia/freedomfrom/tree/prototype/v1-commit-flow) — a single throwaway HTML file, all three personalities, all seven steps, with the two amendments below applied to the winner.

> **Amended in wording by [ADR 0007](./0007-a-line-with-spurs.md).** *The only ceremony in the app is the hold that commits you* becomes **the hold means this cannot be undone**: clean slate is held too, on the longest hold in v1. Same gesture, same meaning, one more place. The rule of one statement and one action is untouched and is now an invariant with no exceptions.

## The decided flow

| Step | Drawn by | Shape |
|---|---|---|
| **First run** | app | Two sentences — what it does, and that you will not be able to undo it — then the collateral at full weight: *while it runs, no app on this phone can be deleted, not just this one, and the clock stays automatic.* Then "Begin". |
| **Targets** | app + system picker | A count and a field of tiles. Typed websites listed beneath as plain text; applications are a number, because iOS never lets the app name them. |
| **Commit** | app | A short list of durations, tapped. The resulting deadline in words beneath it. Then **hold to commit** — the hold *is* the confirmation; there is no dialog. |
| **Shielded** | ShieldConfiguration extension | A countdown in the dark. No app name, no explanation, no button, no scolding. |
| **Escape** | app | Where the exit is, that it takes about fifteen seconds, that it will be written down, that the other two routes do not work, and the honest ceiling. Four lines, no argument. |
| **Expiry** | app + Monitor extension | The screen turns light and says "Ended." |
| **Re-arm** | app | The countdown again, indistinguishable from a normal launch. |

Seven steps, not the six the ticket listed. Re-arm after delete-and-reinstall was added during the prototype: ADR 0001 requires the re-arm to be silent, and silence still needs a screen designed for it.

> **The duration list is provisional above one week.** Its rows stop at seven days because `DeviceActivityCenter` caps a single *schedule* there — not because a week is the intended ceiling. v1 is required to express longer commitments; what replaces the top of the list, and what wakes the extension across a month, waits on [Decide whether v1 caps a commitment at one week or chains intervals](https://github.com/SamuelColacchia/freedomfrom/issues/16). Nothing else on this page depends on it: the deadline is already an arbitrary absolute instant (ADR 0002), and the tapped-list *shape* is what was decided here, not its last row.

**Web domains are typed by hand, not chosen in the picker.** Application tokens are opaque, so a typed domain is the only part of a target set the app can read back to you — and it is the only thing on the targets screen that is words rather than a count.

> **Superseded in part by [ADR 0006](./0006-web-targets-block-by-filter-not-by-shield.md).** Typed domains survive; the mechanism assumed here does not. A typed domain cannot be shielded at all — it is applied through `webContent.blockedByFilter` instead, so a blocked website shows Apple's own page rather than the countdown in the dark, and the "Shielded" row above is app-only. The targets step also gains one web-specific line. Everything else on this page stands.

## Two amendments to what was prototyped

**The duration slider is replaced by a discrete tapped list.** The prototype's slider looked continuous but snapped to seven presets, so it was a costume over a list — and one drag to the end bought the maximum commitment for exactly the effort of the minimum. A commitment is a discrete, irreversible choice and its control should feel like one. This also leaves the hold as the only continuous gesture in the app, so the single drag-like action is the one that actually binds you.

**The restrictions sentence at first run moves out of grey whisper type into full weight.** ADR 0001 deliberately provides no setup ritual, which makes first run the *only* moment informed consent can happen. The device-wide deletion block is the most surprising consequence of committing and it was the line most likely to go unread.

## Considered options

**The mix (provisionally chosen, then overturned).** Before the artifact was examined the plan was to take the best individual screens from each personality: the technical preflight for consent, the signature-line hold for commit, the dark countdown for the shield, a prose refusal above a route table at the escape. Every screen in that set is defensible on its own and it was rejected anyway. A mix buys the best screens at the cost of the product: a dense status panel followed by a serif contract followed by a dark room is three voices with a seam at each join, and it would have committed the build to two type treatments. One coherent product beat a collection of locally-optimal screens — and once the slider went, the reason the mix existed at all (B's commit was too easy to fire by accident) went with it.

**The Contract, whole (rejected).** Ceremonial and argued throughout. It wins the commit moment outright and its escape screen is the best argument in the prototype, but a shield that explains itself is a shield that negotiates, and the shield is the screen seen most often.

**The Instrument, whole (rejected).** The most honest artifact in the prototype and the only one whose escape screen admits in a column heading that revoking works. It loses on the two screens that matter most to a person rather than a developer: an ISO timestamp on a lock screen is cold, and its token table shows hex ids that mean nothing to anyone who did not write the app.

## Consequences

- **The shield is not an information surface.** It says nothing, so every fact about a running commitment — remaining time, deadline, degraded coverage — has to be reachable inside the app. The spec cannot assume the user learns anything from the shield beyond that time remains.
- **Consent rests on one sentence.** There is no preflight panel and no ritual to fall back on. If a tester ever says "I didn't know it would stop me deleting other apps", the fix is that sentence, not a new screen. That makes it a testable claim rather than a design opinion.
- **The product does not defend itself at the escape.** B states where the exit is, that it is recorded, and that the other routes do not work — then stops. Accepted knowingly: the one moment a user most wants an argument is the moment they get four lines. The alternative was importing another voice for a single screen.
- **The history is the only place a break is visible**, since expiry does not celebrate and re-arm does not confront. Consistent with ADR 0001's quiet record, but it has to be reachable from screens that are deliberately wordless — a navigation problem the build spec has to solve rather than inherit. **Solved by [ADR 0007](./0007-a-line-with-spurs.md)**: a pushed spur off the targets root, reachable only when nothing is running, and absent from the screen when there is no history.
- **Committing is a tap then a hold.** If it proves too easy in use, the fix is lengthening the hold, not adding a confirmation dialog — a dialog is a second tap, not a second thought.
- **One type treatment, not two.** A direct consequence of picking one personality instead of the mix.
- **A `ShieldAction` extension stays deferred.** ADR 0002 deferred it because a shield button would have nothing to do; the decided shield has no button at all.
- **The prototype is thrown away, not promoted.** It was written under prototype constraints — no tests, no error handling, no persistence. The decided flow gets rewritten properly when the v1 build spec is synthesized.
