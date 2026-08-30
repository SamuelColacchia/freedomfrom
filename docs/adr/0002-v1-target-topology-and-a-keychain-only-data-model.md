# v1 target topology, identifiers, and a Keychain-only data model

freedomfrom v1 is three signed targets — the app, a `DeviceActivityMonitor` extension, and a `ShieldConfiguration` extension — plus a local SwiftPM package holding the shared domain logic. All persistent state lives in a single Keychain record shared through a keychain access group; there is **no App Group**. The app is universal with a floor of iOS 26.0, and each device runs its own commitments independently of the other.

## Targets and identifiers

Team ID `6989TSP54U`, Individual enrolment, automatic signing.

| Target | Type / extension point | Bundle ID |
|---|---|---|
| `FreedomFrom` | application | `com.samuelcolacchia.freedomfrom` |
| `Monitor` | app-extension · `com.apple.deviceactivity.monitor-extension` | `com.samuelcolacchia.freedomfrom.monitor` |
| `ShieldConfig` | app-extension · `com.apple.ManagedSettingsUI.shield-configuration-service` | `com.samuelcolacchia.freedomfrom.shieldconfig` |
| `FreedomFromKit` | local SwiftPM package — no App ID, not signed | — |

Every signed target carries exactly two entitlements: `com.apple.developer.family-controls`, and a keychain access group of `$(AppIdentifierPrefix)com.samuelcolacchia.freedomfrom`.

Shared build settings: `IPHONEOS_DEPLOYMENT_TARGET 26.0`, `TARGETED_DEVICE_FAMILY "1,2"`, `CODE_SIGN_STYLE Automatic`, `DEVELOPMENT_TEAM 6989TSP54U`. Both extensions and the package build with `APPLICATION_EXTENSION_API_ONLY YES`; the extensions also set `SKIP_INSTALL YES`.

## The data model

One Keychain record, access group `$(AppIdentifierPrefix)com.samuelcolacchia.freedomfrom`, `kSecAttrAccessibleAfterFirstUnlock`, explicitly non-synchronizable. It holds:

- the **active commitment** — started-at, absolute deadline, encoded `FamilyActivitySelection`, and whether it is degraded;
- the **commitment history** — closed commitments and their outcomes.

Shields and restrictions go through one named `ManagedSettingsStore`, which the framework shares between the app and its extensions without any container.

Three rules follow, and they are the point of the design:

- **The deadline is authoritative.** It is absolute wall-clock time, and nothing shortens it. Both the app and the monitor extension reconcile against it rather than trusting a `DeviceActivity` callback to arrive.
- **A token that no longer resolves degrades coverage, never duration.** Apple documents selection tokens as opaque and practitioners report real churn across reinstalls, so this fires precisely on the delete-and-reinstall path. The unresolvable target is dropped from the applied shield, the commitment is marked degraded, and the deadline stands.
- **A break is a surviving record met by a fresh install.** Because the record outlives deletion, an app that launches and finds a commitment still running knows it was deleted mid-commitment. That is the only signal available, and it is what makes ADR 0001's "quiet record" possible at all.

## Amended by hardware: the App Group returns, holding one value

> Hardware smoke check S1, run on an iPhone 14 Pro Max on iOS 26.6, came back **red for `ShieldConfig` alone**. This ADR's Keychain-only claim is otherwise unchanged.

`ShieldConfig` has **no Keychain at all**. `SecItemCopyMatching` and `SecItemAdd` both return `errSecNotAvailable` (-25291) from that process, under a signed entitlement verified identical to the app's and the Monitor's: `6989TSP54U.com.samuelcolacchia.freedomfrom`. It is the sandbox, not the configuration. The app and the `Monitor` extension are unaffected — the Monitor released a commitment on time with the app closed, which it could only do by reading this record.

So the deadline reaches `ShieldConfig` through an **App Group**, `group.com.samuelcolacchia.freedomfrom`, and nothing else does.

| | |
|---|---|
| What is mirrored | The running commitment's absolute deadline. Nothing else |
| Written | By the app at commit; cleared by whatever releases |
| Read | By `ShieldConfig` only |
| Authority | **None.** The Keychain record is authoritative and stays the only thing that survives app deletion |
| Storage | An atomic file write in the shared container, **not `UserDefaults`** |

**This is not the mirror this ADR rejected.** That rejection was specific: `UserDefaults` propagation across an App Group is asynchronous and `synchronize()` is a no-op, so a mirror becomes a drift generator and an extension reconciles against a stale deadline. An atomic file write does not have that property, and a deadline has exactly one writer and is immutable for the life of the commitment. A stale mirror could only cost a wrong number on a shield or a late release — never an early one.

**The App Group's original objection dissolved rather than being overruled.** It was dropped for being "an entitlement with no reader". It now has one.

Two things the reversal cost less than predicted, and one it cost more:

- **No portal visit.** `xcodebuild -allowProvisioningUpdates` created the App Group and added it to all three App IDs unattended. This ADR predicted "a portal toggle".
- **No migration**, exactly as predicted, because the mirror holds nothing that outlives a commitment.
- **A release taken by `ShieldConfig` can no longer close the record.** It clears enforcement and the mirror, but cannot write the Keychain. The app on next launch and the Monitor at its next wake both reconcile against the same absolute deadline, so the record closes **late, never wrongly** — the same direction of failure ADR 0004 already accepts.

## Considered options

**A `ShieldAction` extension (deferred, not rejected).** ADR 0001 rules out an in-app escape hatch, so a shield button has no behaviour to implement and the default dismiss is correct. It would be a bundle ID, a provisioning profile, and a memory-starved process bought for nothing. Adding it later is a `project.yml` block and a folder.

**An App Group (dropped).** The project-generation research declared one on every target by convention. Nothing reads it: shared state is in the Keychain, and a named `ManagedSettingsStore` is shared with extensions by the framework itself. An entitlement with no reader still has to exist on the App ID, be present in the profile, and survive signing — on a chain that currently fails headless. Re-adding it later is a portal toggle and a line of YAML per target, with no migration, because by definition it holds nothing.

**A Keychain record with an App Group mirror (rejected).** This is what most practitioners do, so the divergence is deliberate. `UserDefaults` propagation across an App Group is asynchronous and `synchronize()` is a no-op, which makes a mirror a drift generator — and drift here means an extension reconciling against a stale deadline, the exact failure class the commitment-timer research catalogues. One store means there is never a question of which copy is right.

**Cross-device sync (rejected).** The app is universal, but nothing crosses between devices. Enforcement cannot: tokens are device-local and opaque, and authorization is granted per device. The sync actually worth having — the iPad shielding the moment the iPhone commits — needs a CloudKit container and a silent push to even attempt, and is best-effort even then. Every cheaper channel (synchronizable Keychain, `NSUbiquitousKeyValueStore`) only arms the second device when its app is next opened, which is exactly the moment the user is already cooperating. It would look like enforcement without being any.

**Prompting to re-pick targets when tokens break (rejected).** It restores coverage, but "your tokens broke, please re-select" and "select nothing" are the same gesture. It is the lever ADR 0001 refuses to build: an in-app path whose destination is less enforcement.

## Consequences

- **Committing is a per-device ritual.** A commitment on the iPhone does nothing to the iPad. Nothing in the app stops you skipping the second device — an accepted hole, not an oversight, and the honest reason the universal build is two islands rather than one net.
- **`denyAppRemoval` bites per device, independently.** Each device with a live commitment blocks all app deletion on itself, for the commitment's duration.
- **The history is erasable.** Keychain data survives app deletion, which is the whole point, but it also survives a user who wants a genuinely clean slate — so v1 needs a plainly-named erase action rather than a hidden one. Consistent with ADR 0001's stance of naming exits instead of concealing them.
- **The keychain-access-group path to an extension is unverified for this use.** The commitment-timer research listed it under "could not confirm". It is a standard iOS pattern, but it becomes a first hardware smoke check the moment a device is paired.
- **`FreedomFromKit` is the testability seam.** Deadline reconciliation, clamping an interval into the legal 15-minute-to-1-week window, and degrade-on-unresolvable-token are pure logic with no device dependency, so they get real tests that run headless on the Mac via `swift test`. That matters disproportionately while hardware access is still zero.
- **iOS 26.0 excludes most people who could otherwise be invited to TestFlight.** Accepted deliberately: it removes availability ladders from three targets and a package, and the floor is trivially lowered later if a tester turns up on something older.
