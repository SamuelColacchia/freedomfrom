# Screen Time trusted-person and exemption guarantees

**Ticket:** [#74](https://github.com/SamuelColacchia/freedomfrom/issues/74)  
**Date:** 2026-09-04  
**Scope:** individually authorized iPhones, with comparison to child/Family Sharing and supervised modes.

## Bottom line

A trusted person can hold a Screen Time passcode, but on an individually authorized iPhone that passcode does not transfer Family Controls authority from the device owner. Apple’s individual Family Controls flow authenticates the device owner, and Apple documents that revoking authorization stops parental controls and removes restrictions such as preventing app deletion. A helper-controlled recovery account may reduce passcode recovery by the owner, but it does not prevent the owner from revoking the app’s individual Family Controls authorization.

The public APIs do not expose a way for freedomfrom to set, read, verify, or identify ownership of a Screen Time passcode. They also do not expose a trusted-person identity. Do not claim helper-only enforcement from an app API.

## Primary-source findings

### 1. Individual authorization is owner-approved and revocable

Apple says `requestAuthorization(for:)` accepts either a child or individual member; a child requires parent/guardian authentication, while an individual authenticates their own account. After individual authorization, later requests no longer present the biometric authorization sheet. Apple also provides `revokeAuthorization`, and its current reference says revocation means the app no longer provides parental controls and the system no longer enforces restrictions, including preventing app deletion.

Sources: [requestAuthorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)), [revokeAuthorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/revokeauthorization%28completionhandler%3A%29.md).

**Guarantee:** authorization can be revoked by the device owner; revocation is not blocked by a trusted person’s Screen Time passcode.

**Not guaranteed:** that a revoked individual authorization immediately yields a stable status usable as a break detector. Apple’s revoke completion result does not indicate authorization state.

### 2. Screen Time passcode recovery belongs to an Apple Account, not an app

Apple Support says a Screen Time passcode is separate from the device passcode, is required to change Screen Time settings, and may be reset using the Apple Account originally used for Screen Time Passcode Recovery. Apple also says that without that recovery account, the passcode cannot be reset and Apple cannot provide it.

Sources: [set a Screen Time passcode](https://support.apple.com/en-us/126533), [reset a forgotten Screen Time passcode](https://support.apple.com/en-us/102677).

**Guarantee:** if a human genuinely sets a Screen Time passcode and withholds the recovery Apple Account, ordinary Screen Time setting changes require that passcode.

**Not guaranteed for this app:** the app can detect that a passcode exists, verify that a helper chose it, verify that the owner does not know it, or prevent the device owner from using Apple Account recovery. No public Family Controls or Managed Settings API in the cited references provides those operations.

**Recovery caveat:** a helper who owns or can access the recovery Apple Account can reset the passcode without knowing the old passcode. This is a human configuration fact, not an app-verifiable property.

### 3. Always Allowed is a child/Screen Time feature, not an exemption API for Managed Settings shields

Apple’s current parental-controls guidance describes Always Allowed as choosing apps available during Downtime, alongside communication exceptions. The same guidance says Downtime leaves only phone calls and apps chosen to allow available. This documentation is specifically framed around a child’s device and Family Sharing.

Sources: [Screen Time for a child](https://support.apple.com/en-us/108806), [parental controls](https://support.apple.com/en-us/105121).

Managed Settings separately defines `ShieldSettings.applications` as the set of application tokens covered by a shielding view, up to 50 tokens. Managed Settings also has explicit category-policy exceptions: `ShieldSettings.ActivityCategoryPolicy.specific(_:except:)` shields selected activity categories while excluding up to 50 application or web-domain tokens, and `.all(except:)` shields all apps and websites except up to 50 application or web-domain tokens. These are app-controlled Managed Settings policies, not Screen Time Always Allowed.

Sources: [Managed Settings applications](https://developer.apple.com/documentation/managedsettings/shieldsettings/applications-swift.property.md), [specific categories with exceptions](https://developer.apple.com/documentation/managedsettings/shieldsettings/activitycategorypolicy/specific(_:except:)), [all categories with exceptions](https://developer.apple.com/documentation/managedsettings/shieldsettings/activitycategorypolicy/all(except:)), [WWDC22 Screen Time API](https://developer.apple.com/videos/play/wwdc2022/110336/). Apple’s WWDC22 explanation says named Managed Settings stores can coexist and the most restrictive setting wins; it also documents a maximum of 50 named stores per process. Therefore an exception in one store is not a universal allow if another store still applies a more restrictive setting.

**Guarantee:** Apple’s public documentation does not establish precedence between a user’s Always Allowed list and a Managed Settings application shield. The documented app-owned category policies do provide an explicit exception mechanism, but only within that policy and subject to the most-restrictive-setting-wins behavior across stores.

**Product implication:** essential apps can be represented by excluding their opaque application tokens from `shield.applications`, or by passing them as `except` tokens to an app-owned category policy. A helper-only approval flow is not built into Family Controls, but an app could maintain its own approval record and apply approved opaque tokens to these exception sets. That would be app-owned policy, not Apple verification of helper identity, and it cannot override another more restrictive Managed Settings store or Screen Time layer without a hardware probe.

### 4. App exceptions are child approval flows, not trusted-person authorization for an individual

Apple documents app exception requests as a child requesting an exception and a parent/guardian approving or removing it; approved exceptions can later be removed by the parent. This is a Family Sharing/child model. It is not documented as a general API for an individually authorized adult to delegate approval to a helper, and it does not establish precedence over Managed Settings shields.

Source: [app exceptions for a child](https://support.apple.com/en-us/125399).

### 5. Supervision is a different authority model

The cited Family Controls documentation distinguishes child authorization, which requires parent/guardian authentication, from individual authorization, which authenticates the individual on the device. Supervision and device-management restrictions are outside this app’s Family Controls/Managed Settings model and must not be conflated with an individual authorization plus a privately entered passcode.

The repository’s ADR-0001 correctly warned that `.individual` is revocable and that Screen Time passcode state is not exposed to the app, but its external claims are historical context rather than current Apple truth. Current Apple references above supersede it where wording differs.

## Observed hardware versus unknown

### Observed in this repository

- On an iPad running iPadOS 26.6, the 4 September 2026 run reported a revoke followed by `authorization state=Not Determined`, a reauthorization prompt, and coverage returning after approval. The archive did not prove a refusal detector, and a separate revoke-only run recorded no break mark. See [hardware checklist](https://github.com/SamuelColacchia/freedomfrom/blob/c4434f1/docs/hardware-smoke-checklist.md#L267-L306) and [revoke evidence](https://github.com/SamuelColacchia/freedomfrom/blob/c4434f1/docs/evidence/story-revoke-20260904.md#L1-L7).
- On an iPhone 14 Pro Max running iOS 26.6.1, app deletion and manual date/time changes were reported unavailable during an individually authorized commitment. These are one-device observations, not a general Apple guarantee. See [clean-run evidence](https://github.com/SamuelColacchia/freedomfrom/blob/c4434f1/docs/evidence/story-clean-20260904.md#L32-L45).

### Unknown and required human probes

1. Whether a helper-set Screen Time passcode remains effective against every relevant Settings path on an individually authorized adult device.
2. Whether the owner can reset that passcode through the configured recovery Apple Account, and who controls that account.
3. Whether Always Allowed apps remain usable when the same app is also in `ManagedSettingsStore.shield.applications`.
4. Whether `specific(_:except:)` and `all(except:)` behave as documented for selected opaque application and web-domain tokens on the target iOS release.
5. Whether Always Allowed has any effect on a Managed Settings shield versus only Downtime/App Limits.
6. Whether a helper can approve or revoke an app-owned exception on an individual device without Family Sharing/child authorization; the app can model this, but Apple does not authenticate the helper.
7. Whether revocation status is consistently `Denied` or `Not Determined` across current iOS releases and foreground/cold-launch timing.

## Decision boundary for downstream design

- **Optional trusted-person setup:** may be presented as a human commitment aid, not as verified enforcement. The app must not claim it knows who set the passcode, who can recover it, or that the owner cannot revoke Family Controls.
- **Optional solo mode:** is the only mode whose guarantees are fully within this product’s existing individual-authorized model, and it still permits revocation.
- **Helper-only active exceptions:** Apple supplies no helper identity or trusted-person authorization primitive. An app-owned approval flow remains technically possible using opaque application/category tokens and the documented `except` policies, but it is not Apple-verified and must be tested alongside any other restrictions.
- **Essential-app exemptions:** use the app-owned `shield.applications` exclusion or category-policy `except` tokens. Do not describe either as Apple Always Allowed precedence or as a universal exemption across stores.

