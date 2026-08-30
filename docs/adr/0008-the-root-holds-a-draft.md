# The root holds a draft

Targets and Commit keep whatever you last left in them — the chosen apps, the typed web domains, and the chosen length — as a single **draft** persisted in ADR 0002's Keychain record. Committing consumes nothing and abandoning discards nothing. The rule underneath: **every screen in the forward line keeps what you left in it, because friction belongs on the exit and not on the entrance.**

This answers the question [ADR 0007](./0007-a-line-with-spurs.md) opened when it made Targets the root: what the screen shows on arrival.

## What the draft is

| Remembered | How it reads on arrival |
|---|---|
| Chosen applications | A count, as it is for a fresh pick (ADR 0003). Verified by opening the picker sheet, which arrives with them checked |
| Typed web domains | Plain text — the only part of a target set the app can read back to you |
| The chosen length | Its row selected, with the deadline sentence beneath recomputed from now |

The draft is written when the picker sheet returns, when a typed domain is committed with return, and when the app backgrounds. So a finished domain always survives an interruption and a half-typed one never does.

**A remembered length is a length, never a stored date.** ADR 0004's date picker can produce a deadline that has since passed, so a custom row reads "100 days" and the sentence beneath it recomputes from today.

## Why the entrance is untaxed

ADR 0001 puts every gram of friction in this design on getting out. Re-assembling a target set would have been the first tax on getting in, which is the act the whole product exists to encourage — and it lands hardest on the interrupted user, who loses fifteen typed domains to a phone call and gets no warning that they were about to.

Careless committing is already guarded twice, and both guards scale with the size of the mistake. ADR 0003 puts the resulting deadline in words under the duration list, so a remembered year reads *until 29 August 2027* before the hold is touched. ADR 0004 lengthens the hold with the duration, so the gesture is longest exactly where an unintended commitment costs most.

**The honest cost: apps are a count, so a set assembled a month ago can be committed to without being looked at.** That is the price of the answer, not an oversight. The picker that reads it back is the same one tap that re-picking would have cost.

## Clean slate takes the draft

The one erase in the app reaches everything you authored: the history and the draft. Targets is blank afterwards.

ADR 0002 created clean slate because the Keychain record outlives app deletion, so a user who wants nothing of theirs left in the app has no other route. A surviving list of the apps and sites you block is the most personal residue there is. Left behind, it would also make the longest hold in v1 the only gesture with no visible effect: you hold, go Back, and land on a Targets screen that looks exactly as it did.

Two things this does not change. **First run still shows once, ever** (ADR 0007), so a clean slate lands on a blank Targets rather than back at "Begin". And the draft still survives delete-and-reinstall, because the whole record does (ADR 0002) — though a re-arming app lands on the countdown, so it is not seen until that commitment closes.

## Only you edit the draft

Nothing prunes it. A token that no longer resolves stays in the draft, and a commitment made from it is marked degraded like any other (ADR 0005).

ADR 0002 rejected prompting to re-pick when tokens break, on the grounds that "your tokens broke, please re-select" and "select nothing" are the same gesture. Pruning is that move with the prompt deleted: it quietly reduces what you will block next time. It would also act on a signal that is not yet known to exist — whether an unresolvable token is detectable at all is on ADR 0005's hardware smoke checklist — and a false positive permanently deletes a target the user chose.

**A commitment can therefore be degraded at birth**, which needs no new concept: the shield is a precondition (ADR 0005), so as long as one target applies the commitment exists, coverage is recomputed, and it reads degraded.

## Considered options

**Opening blank every time (rejected).** Every commitment a fresh deliberate choice, and no commitment possible without looking at what it blocks. It buys deliberation the deadline sentence and the scaled hold already provide, and charges for it by making a re-typed list of twenty domains the price of every commitment.

**Remembering typed domains only (rejected).** Keep the words, drop the opaque tokens, so every app token is freshly minted and freshly seen — which also closes the born-degraded path at source. It needs a second rule about which half of a target set is remembered, and it makes hunting five apps through the system picker a permanent per-commitment cost, to buy back a deliberation that is already bought.

**A receipt rather than a draft (rejected).** The root shows the last commitment's targets, and edits abandoned before the hold are discarded. It has the appeal that the root always shows something once real, but calling an abandoned edit unreal is the app second-guessing what the user left on screen, and nothing else in this design does that. It also needs a second stored selection to express what one field already expresses.

**Abandoned edits in memory only (rejected).** Committed sets persist, interrupted ones survive a Back and die whenever iOS next kills the app. This is what writing no persistence code produces, and its behaviour turns on a background kill the user cannot see, so identical actions give different screens on different days.

**The duration named fresh every time (rejected).** The list always arrives unselected, on the reasoning that the length is the one parameter setting how much a mistake costs. The thing that makes a remembered app set risky is absent here: the consequence is spelled out in words beneath the list, so a remembered length cannot be committed blind. Forgetting it buys one tap of attention and costs the core loop a third gesture.

**Pruning dead tokens from the draft (rejected).** See above. The draft would self-heal and the Targets count would always be live, at the price of the app editing the user's list without telling them, in a product with no voice for telling them.

**Clean slate erasing the history only (rejected).** The draft as a working surface rather than a record, matching the glossary as it was written before a draft existed. It asks the user to hold a distinction nothing else in the app asks them to hold, and leaves the residue that clean slate exists to remove.

**A clear action on Targets (rejected).** An explicit way to empty the draft without going through the history. The picker and the text field already empty it, and the root is the busiest screen in the app (ADR 0007) — a fourth control there costs more than the gesture it saves.

## Consequences

- **The core loop is two gestures.** Open the app, Next, hold. Everything about a returning commitment is inherited; only the hold is spent.
- **ADR 0005's empty-selection gate becomes near-invisible.** The commit screen is unreachable with nothing selected, but a returning user always satisfies that on arrival, so the gate bites only on the first commitment ever and on the first after a clean slate.
- **The draft and the active commitment are independent copies.** ADR 0002 already stores the commitment's own encoded selection, so a draft edited after a commitment closes, or left holding a token that commitment dropped, costs nothing to reconcile.
- **`CONTEXT.md` gains draft as a term, and clean slate is rewritten** to erase everything authored rather than the history alone.
- **A draft with no history has no route to clean slate**, since ADR 0007 hides the history line when the history is empty. Accepted: the picker and the text field empty a draft by hand, and nothing is locked away.
- **One hardware smoke check is added**: that a `FamilyActivitySelection` decoded from the Keychain and handed back to `FamilyActivityPicker` arrives with its apps checked. The whole answer rests on it, and it cannot be verified off-device.
- **`FreedomFromKit` gains the draft**, alongside deadline reconciliation, the walk-forward step, and coverage. Persisting, restoring, and clearing it are pure logic, so they are headless-testable on the Mac.
