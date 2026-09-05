# Issue 67: Screen Time commitment lifecycle facts

**Status:** Resolved for documented platform facts; hardware gates remain explicit.
**Scope:** lifecycle, scheduling, and Managed Settings store composition. Filters and passcodes are out of scope.
**Checked:** 2026-09-04. Sources were current Apple Developer documentation pages retrieved in 2026.

## Findings

### 1. A `DeviceActivitySchedule` is a monitoring interval, not enforcement

Apple describes `DeviceActivitySchedule` as a calendar-based schedule for **when to monitor** activity, with `intervalStart`, `intervalEnd`, and `repeats`. `DeviceActivityCenter` says activity begins and ends when the device is first used inside or outside the interval, and callbacks are invoked when the device is in use. Therefore a schedule cannot be treated as an absolute deadline callback or as the thing that holds a shield.

- [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule.md)
- [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter.md)

This supports the existing failure direction: enforcement must be applied independently and release reconciliation must compare the stored absolute deadline with `now`.

### 2. Apple documents numeric monitoring bounds and cross-store composition

Apple documents that the minimum interval length for monitoring device activity is **15 minutes**, and the maximum interval length for monitoring device activity events is **one week**.

- [intervalTooShort](https://developer.apple.com/tutorials/data/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort.json) — “The minimum interval length for monitoring device activity is fifteen minutes.”
- [intervalTooLong](https://developer.apple.com/tutorials/data/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltoolong.json) — “The maximum interval length for monitoring device activity events is one week.”

These are monitoring-window bounds, not necessarily commitment-duration bounds. A one-minute **commitment** can still be represented by applying Managed Settings immediately and reconciling against a one-minute absolute deadline; a one-minute **Device Activity monitoring interval** is rejected by the documented minimum. The repository already encodes the distinction: commitment length clamps to 15 minutes ([Length.swift](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/FreedomFromKit/Sources/FreedomFromKit/Length.swift#L1-L12)), while each watchdog window is seven days ([Types.swift](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/FreedomFromKit/Sources/FreedomFromKit/Types.swift#L156-L164)).

Apple’s WWDC22 Screen Time presentation documents the previously missing composition fact: up to **50 Managed Settings stores per process**, each with a unique name; named stores are shared between the app and its extensions; and **“The most restrictive setting always wins.”** The presentation demonstrates clearing a Social store while a Gaming store continues shielding gaming websites.

- [WWDC22 “What’s new in Screen Time API”, Managed Settings Store segment](https://developer.apple.com/videos/play/wwdc2022/110336/) (approximately 5:13)
- [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore.md)
- [ManagedSettingsStore.Name](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/name.md)

**Conclusion for downstream concurrency decisions:** cross-store composition is documented and viable at the framework level. The product still needs to choose whether each commitment gets a named store, but the earlier report’s claim that composition was wholly undocumented was wrong. A device probe remains appropriate for this app’s exact combination of shields, web filters, restrictions, and release timing; it is not a reason to treat one shared store as the only settled design.

### 3. What remains to verify for this app’s composition

The WWDC22 demonstration settles the framework-level rule: uniquely named stores are shared across the app and extensions, up to 50 stores may exist per process, and the most restrictive setting wins. What remains unknown is not whether cross-store composition exists, but how this app’s particular combination behaves in a real release cycle: shields, web filters, device-wide restrictions, and one commitment releasing while another remains active.

That is a hardware validation question, not an absence of platform support. The product-design ticket should choose the store ownership model explicitly rather than inherit the current single-store implementation by default.

### 4. Indefinite commitments are not represented by the documented schedule API

The documented schedule requires an interval start and end. Apple does not document an indefinite schedule or a schedule that itself persists without an end. Managed Settings has no documented expiry in the cited store API page, but that is not evidence of an indefinite commitment contract: it only means the settings are app-managed until changed, subject to the system’s effective-state rules.

**Conclusion:** an indefinite commitment cannot be claimed as a platform-supported schedule primitive. If product meaning requires “until manually released,” that release policy must be separately specified and tested; it must not be smuggled in as a very distant `DateComponents` interval.

### 5. Authorization can change externally

Apple says authorization status can change because of external events, including a parent or guardian changing status in Settings, and provides `authorizationStatus` and revocation APIs. The same page documents `.individual` authorization with Face ID or Touch ID.

- [AuthorizationCenter](https://developer.apple.com/documentation/familycontrols/authorizationcenter.md)

This supports treating authorization loss as an escape route and requiring reconciliation, not treating a schedule callback as proof that enforcement still exists.

## Known limits and human probes

The following facts are not settled by documentation or by this Linux-side inspection:

1. Whether two overlapping `DeviceActivity` activities reliably coexist on the target iOS release, and callback ordering at overlap boundaries. This is separate from the documented named-store composition rule.
2. Whether this app’s combination of shields, web filters, and device-wide restrictions has the expected effective state when one named store releases while another remains active.
3. Whether a long-running or effectively indefinite commitment remains enforced across reboot, app deletion/reinstallation, authorization revocation/regrant, OS update, and prolonged device inactivity.
4. Whether a far-future schedule is accepted and delivered after powered-down periods. Apple’s docs do not promise this.

Required device probes: run paired commitments with (a) disjoint targets and (b) one shared target, using separate named stores; release the earlier commitment while the later remains active; inspect both enforcement and logs; repeat across reboot and app termination. Separately attempt the longest practical interval and document whether `startMonitoring` accepts it and whether callbacks arrive. Do not mark these rows from simulator or source inspection alone.

## Repository application

The current implementation registers one activity name and stops that name before re-registering the next window: [Enforcement.swift, lines 25-32 and 88-102](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/Sources/Shared/Enforcement.swift#L25-L32). It applies and releases all commitment settings through one named store: [lines 31-85](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/Sources/Shared/Enforcement.swift#L31-L85). These are implementation observations, not new product decisions.

## Source quality

Apple Developer documentation is primary evidence. Apple Developer Forums were checked only as anecdotal corroboration of uncertainty around multiple schedules and callback reliability; forum reports are not used to settle platform facts.
