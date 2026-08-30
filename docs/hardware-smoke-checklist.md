# Hardware smoke checklist

Everything about freedomfrom that only a real device can answer, in the order a human runs it. Decided in [ADR 0009](./adr/0009-a-foundation-only-kit-and-a-hardware-pass-a-human-walks.md).

Read this before starting:

- **Two checks can block.** S1 and S2 change the architecture when red, so they run on the walking skeleton, before v1 is written. Everything else fires a pre-bound amendment instead — a decision, not a reopening.
- **Every check names its amendment.** If one goes red, apply the amendment written beside it and amend the ADR. Do not reopen the decision.
- **Order is not arbitrary.** The destructive checks live in their own commitment because a break contaminates every later observation, and inside that run the revoke comes before the delete, because a working `denyAppRemoval` prevents deleting the app.
- **Honest scope.** These prove what happened on one device, on one OS build, once. Nothing here licenses a general claim.

## Prerequisites

- [ ] An iPhone paired to the Mac build host, with Developer Mode on, cabled
- [ ] A working Apple Developer identity on the Mac (issue #13)
- [ ] The walking skeleton installed on the device
- [ ] A second app installed that you are willing to try to delete, and a website you can reach

## Evidence

The record is a sysdiagnose pulled off the device, read on the Mac. `log stream --device` does not exist on macOS 26.6 and `devicectl` has no log subcommand, so live viewing means Console.app on the Mac and is optional.

```sh
# Confirm the device is visible
xcrun devicectl list devices

# Capture (confirm flags against --help; unverified until a device is paired)
xcrun devicectl device sysdiagnose --device <udid> --output-directory ./evidence

# Read, filtered to our subsystem
log show --archive ./evidence/<bundle>/system_logs.logarchive \
  --predicate 'subsystem == "com.samuelcolacchia.freedomfrom"' \
  --info --debug --style compact
```

One capture at the end of each commitment run, not one per check. A sysdiagnose is hundreds of megabytes and takes minutes.

---

## Phase 0 — the channel itself

**E1. Does a sysdiagnose contain our subsystem at all?**
Launch the skeleton, let it log one line, capture, and filter.
**Green**: at least one line from `com.samuelcolacchia.freedomfrom` in the archive.
**Red**: fall back to Console.app with the device selected and the subsystem in the filter field. If neither works, no other check on this page can produce evidence — stop and solve this first.

---

## Phase 1 — the skeleton, before v1 is written

Build and launch for the **Simulator first**. It needs no signing, so a failure there is a code failure rather than a signing one. Then install on the device.

**S1. Can an extension read the Keychain access group? (gate)**
Grant authorization, pick one app, commit a short window so a record is written. Open the shielded app to wake `ShieldConfig`, and let the monitor wake at a window boundary.
**Green**: `monitor` and `shieldconfig` categories both log a successful record read with the deadline they found.
**Red → amendment**: re-add the App Group to all three targets. ADR 0002 rejected it for having no reader; this gives it one. A portal toggle and a line of YAML per target, no migration, because it holds nothing.

**S2. Can `ShieldConfig` mutate a `ManagedSettingsStore` inside its memory budget? (gate)**
With a commitment whose deadline has already passed, open a shielded app so `ShieldConfig` runs and tries to clear the store.
**Green**: `shieldconfig` logs the mutation landing, and the shield is gone on the next open. No jetsam.
**Red → amendment**: ADR 0004's third reconciliation point is replaced by its deferred local notification, and ADR 0005's self-shield fix is dropped — a user who shields freedomfrom keeps it shielded. Both ADRs are amended together; they rest on the same premise.

**S3. Does a selection decoded from the Keychain hand back to the picker with its apps checked?**
Store a selection, kill the app, relaunch, open the picker.
**Green**: previously chosen apps appear checked.
**Red → amendment**: ADR 0008's draft keeps only the web domains and the length. Apps are re-picked every time. Cannot block a build, but it deletes a decided behaviour, so it is observed here rather than a month later.

---

## Phase 2 — the clean run

One 15-minute commitment, one app target and one typed web domain. Nothing in this phase breaks anything.

**C1. First run states what it costs.**
**Green**: the consent sentence is visible before the hold, and the authorization prompt appears.

**C2. The shield applies.**
Open the app target.
**Green**: Apple's shield replaces it. `app` logs enforcement applied with a resolved-of-named count.

**C3. Which browsers does the filter actually cover?**
Load the blocked domain in Safari, then Chrome, Firefox, Brave, and an in-app `WKWebView` in any app that has one. Record each separately.
**Green**: nothing to be green about — this is a survey. Write down exactly which ones blocked.
**Amendment either way**: the targets step names only the browsers observed. If only Safari blocked, it says Safari. It never generalizes. ADR 0006 leaves that half of the line empty until this is filled.

**C4. Does a bare domain cover its subdomains?**
Having typed `example.com`, try `www.example.com` and `m.example.com`.
**Amendment either way**: if subdomains are not covered, canonicalization stands unchanged (ADR 0006 refuses to guess at matching rules) and the user types each host. If they are covered, that becomes a claim the targets step may make.

**C5. Private Browsing is off while the filter holds.**
Open Safari's tab switcher.
**Green**: Private Browsing unavailable. Documented by Apple; confirmed here because the targets step says so.

**C6. Do the restrictions bite under `.individual`?**
Try to delete the *other* app from the Home Screen. Then open Settings and try to switch off automatic date and time.
**Green**: both refused.
**Red → amendment**: the first-run consent sentence drops whichever claim it cannot keep. This is the check that matters most before a stranger installs the app, because ADR 0003 rests all of informed consent on that one sentence.

**C7. Coverage reads true.**
**Green**: the countdown states the number of targets actually enforced, not the number named at commit.

**C8. The release arrives.**
Wait out the deadline. Do not open the app.
**Green**: enforcement lifts. Note how late it was — late is the accepted direction, early is not. The history row reads completed.

**C9. Capture.** Sysdiagnose, filter, save alongside this file's results table.

---

## Phase 3 — the sacrificial run

One longer commitment, deliberately broken. Everything here marks it, which is why it is a second commitment.

**X1. Revoke authorization.**
Settings → Screen Time → freedomfrom → revoke. Relaunch the app.
**Green**: the commitment is marked broken exactly once, and the countdown still runs to the same deadline.

**X2. Does `requestAuthorization` re-prompt from `.denied`?**
On that relaunch.
**Green**: a prompt appears; granting it re-arms coverage.
**Red → amendment**: none needed. ADR 0005 pre-decided this degrades into the never-ask option at the cost of one wasted call per launch. Record it and move on.

**X3. Delete and reinstall.**
Only possible after X1, because a working `denyAppRemoval` blocks it. Delete the app, reinstall, launch.
**Green**: the app finds the commitment still running, marks it broken, and re-arms with no comment. The deadline is unchanged.

**X4. Is an unresolvable token detectable at all?**
On that same relaunch, compare the resolved count against the named count.
**Green**: if any token churned across the reinstall, coverage shrinks and the commitment is marked degraded.
**Red → amendment**: if unresolvable tokens are indistinguishable from resolvable ones, the whole degradation path is unreachable. Coverage states the named count, ADR 0005's degraded row is annotated as unobservable, and ADR 0008's "degraded at birth" becomes moot. Nothing is built to detect what cannot be detected.

**X5. History and clean slate.**
Let it reach its deadline. Check the history row. Then run a clean slate.
**Green**: the row reads broken; the clean slate erases the history and the draft together, on the longest hold in the app.

**X6. Capture.** Sysdiagnose, filter, save.

---

## Results

Fill in and commit. A red result should link the ADR amendment it triggered.

| Check | What it decides | Result | Evidence | Amendment fired |
|---|---|---|---|---|
| E1 | The evidence channel works | | | |
| S1 | Keychain access group from an extension (gate) | | | |
| S2 | `ShieldConfig` can mutate the store (gate) | | | |
| S3 | Selection round-trips into the picker | | | |
| C1 | Consent sentence and prompt appear | | | |
| C2 | The shield applies | | | |
| C3 | Which browsers the filter covers | | | |
| C4 | Bare domain versus subdomains | | | |
| C5 | Private Browsing off while filtering | | | |
| C6 | Restrictions bite under `.individual` | | | |
| C7 | Coverage reads true | | | |
| C8 | The release arrives, and how late | | | |
| X1 | Revoke marks broken once | | | |
| X2 | Re-prompt from `.denied` | | | |
| X3 | Delete and reinstall re-arms | | | |
| X4 | Unresolvable tokens are detectable | | | |
| X5 | History and clean slate | | | |

**Before the first TestFlight invite**: both runs done, and every claim the app makes reconciled against what they showed. Not every check green — nobody can prove what Brave does with a filter, and the app already handles that by naming no browser.
