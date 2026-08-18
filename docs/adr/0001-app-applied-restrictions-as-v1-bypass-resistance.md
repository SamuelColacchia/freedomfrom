# App-applied restrictions, not a setup ritual, as v1's bypass resistance

freedomfrom is a self-restraint blocker: the person it blocks is the person who installs it, and there is no second keyholder. v1 resists bypass using only what the app can apply itself under `.individual` Family Controls authorization — the shield, plus `denyAppRemoval` and `requireAutomaticDateAndTime` — and asks the user for no setup ritual at all.

**The honest claim, which the app's own copy may never exceed: freedomfrom resists casual bypass while authorized. It cannot prevent a determined bypass.**

## The three escape routes

| # | Escape route | Closed by | Confidence |
|---|---|---|---|
| 1 | Settings → Screen Time → *[app]* → revoke authorization | **Nothing.** Only supervision closes it, and supervision requires erasing the device. | `.individual` being user-revocable is **documented**; that device authentication alone suffices is **forum-reported** |
| 2 | Delete the app | `store.application.denyAppRemoval = true`, applied for the commitment's duration | the API is **documented**; that it takes effect under `.individual` is **forum-reported** |
| 3 | Move the device clock forward | `store.dateAndTime.requireAutomaticDateAndTime = true`, applied for the commitment's duration | the API is **documented**; that it takes effect under `.individual` is **forum-reported** |

Route 1 dominates the other two: revoking authorization clears the app's managed settings, so it defeats routes 2 and 3 in the same gesture. Apple also warns that Managed Settings does not guarantee that configured settings govern device behaviour, and there is no way to read back whether a restriction actually took effect. Routes 2 and 3 are therefore **probable, not certain**, until verified on physical hardware — that verification is the first thing to run once devices are paired.

Sources: [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore), [denyAppRemoval](https://developer.apple.com/documentation/managedsettings/applicationsettings/denyappremoval-swift.type.property), [requireAutomaticDateAndTime](https://developer.apple.com/documentation/managedsettings/dateandtimesettings/requireautomaticdateandtime-swift.property), [AuthorizationCenter](https://developer.apple.com/documentation/familycontrols/authorizationcenter), [forum: individual authorization can be disabled with device authentication](https://developer.apple.com/forums/thread/727291).

## Considered options

**A Screen Time passcode ritual (rejected).** Onboarding would walk the user through setting a Screen Time passcode and enabling Content & Privacy Restrictions. It was rejected on three grounds: it does not close route 1 either, so it adds a second lock to a door whose first lock is already open; its one documented win — Content & Privacy Restrictions → iTunes & App Store Purchases → Deleting Apps → Don't Allow — is already covered app-side by `denyAppRemoval` for free; and **there is no public API to set, verify, or even detect a Screen Time passcode**, so every commitment would rest on an unverifiable self-report.

**Supervision (rejected for v1, documented as the only strong option).** Supervising a device via Apple Configurator with supervised restrictions is the one mechanism that genuinely holds up. Apple requires the device be erased to supervise it, which is unacceptable for a daily driver, and no TestFlight tester will ever do it. It is recorded in the README as the honest answer for anyone who wants real enforcement — not built.

## Consequences

- **No setup ritual means no divergence between users.** A TestFlight tester's first run is identical to the developer's; there is no weaker "stranger mode" to design, and no ritual to detect or nag about.
- **Restrictions are always on for a commitment's duration**, with no per-commitment toggle. A toggle would be a lever the user's future weak self pulls at commit time. The collateral is accepted knowingly and explained once at first run: `denyAppRemoval` is device-wide, so **no app can be deleted while a commitment runs** — up to a week.
- **There is no in-app escape hatch.** Route 1 already is one, at roughly fifteen seconds. Anything slower would never be used; anything faster would be a pure downgrade. The app names the Settings exit plainly instead of hiding it.
- **The deadline is absolute wall-clock time**, reconciled against by both the app and the monitor extension. It expires on schedule whether or not the app exists, which makes delete-and-wait a complete escape from any commitment. This is accepted and stated rather than mitigated.
- **A commitment record persists in the Keychain** and survives app deletion. On reinstall the app re-arms silently, without confrontation — the iOS authorization prompt is unavoidable, but the app does not editorialise about the break.
- **Breaks leave a quiet record.** Broken commitments are marked in the commitment history, visible only if the user goes looking. Enforcement cannot stop the user; an honest mirror is what the app can offer instead.
