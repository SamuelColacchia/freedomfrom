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

### 2. Apple documents a monitoring limit and schedule validation, but not overlap semantics

Apple exposes `MonitoringError.excessiveActivities`, `intervalTooLong`, and `intervalTooShort` as possible failures when starting monitoring. The official search result describes the first as monitoring too many activities and the latter two as invalid interval lengths. The public API documentation does **not** state that overlapping non-repeating intervals merge, cancel, serialize, or invoke callbacks in a defined order.

- [MonitoringError](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror)
- [excessiveActivities](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/excessiveactivities)
- [stopMonitoring(_:)](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/stopmonitoring(_:))

**Conclusion for downstream concurrency decisions:** do not infer that multiple commitments can safely own independent schedules. The API permits named activities and stopping named activities, but overlapping callback and replacement behavior remains undocumented. A human device probe is required before choosing a concurrency model.

### 3. `ManagedSettingsStore` supports named store composition, but Apple does not define conflict resolution for overlapping writers

Apple documents a `ManagedSettingsStore` as a data store that applies settings to the current user or device. Setting a value to `nil` deletes that app’s configuration for that setting, while the system determines its effective state from all settings it receives. Apple separately documents that stores with the same `ManagedSettingsStore.Name` share settings and distinct names create distinct stores.

- [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore.md)
- [ManagedSettingsStore.Name](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/name.md)

This establishes that a single named store is a valid composition mechanism, but leaves an important product question unresolved: if commitment A and B overlap and A releases by setting shared fields to `nil`, Apple documents no per-writer ownership or subtraction operation. Separate named stores may avoid that particular overwrite, but Apple does not document how effective settings combine across stores for shields, filters, or restrictions.

**Conclusion for downstream concurrency decisions:** preserve one shared-store commitment as the only settled design. Any multi-commitment composition needs a hardware experiment covering same-target and disjoint-target overlap, release of the earlier commitment, and whether the later commitment remains effective.

### 4. Indefinite commitments are not represented by the documented schedule API

The documented schedule requires an interval start and end. Apple does not document an indefinite schedule or a schedule that itself persists without an end. Managed Settings has no documented expiry in the cited store API page, but that is not evidence of an indefinite commitment contract: it only means the settings are app-managed until changed, subject to the system’s effective-state rules.

**Conclusion:** an indefinite commitment cannot be claimed as a platform-supported schedule primitive. If product meaning requires “until manually released,” that release policy must be separately specified and tested; it must not be smuggled in as a very distant `DateComponents` interval.

### 5. Authorization can change externally

Apple says authorization status can change because of external events, including a parent or guardian changing status in Settings, and provides `authorizationStatus` and revocation APIs. The same page documents `.individual` authorization with Face ID or Touch ID.

- [AuthorizationCenter](https://developer.apple.com/documentation/familycontrols/authorizationcenter.md)

This supports treating authorization loss as an escape route and requiring reconciliation, not treating a schedule callback as proof that enforcement still exists.

## Known limits and human probes

The following facts are not settled by documentation or by this Linux-side inspection:

1. Whether two overlapping `DeviceActivity` activities reliably coexist on the target iOS release, and callback ordering at overlap boundaries.
2. Whether distinct named `ManagedSettingsStore`s combine monotonically, replace one another, or have setting-specific effective-state behavior when one releases.
3. Whether a long-running or effectively indefinite commitment remains enforced across reboot, app deletion/reinstallation, authorization revocation/regrant, OS update, and prolonged device inactivity.
4. Whether a far-future schedule is accepted and delivered after powered-down periods. Apple’s docs do not promise this.

Required device probes: run paired commitments with (a) disjoint targets and (b) one shared target; release the earlier commitment while the later remains active; inspect both enforcement and logs; repeat across reboot and app termination. Separately attempt the longest practical interval and document whether `startMonitoring` accepts it and whether callbacks arrive. Do not mark these rows from simulator or source inspection alone.

## Repository application

The current implementation registers one activity name and stops that name before re-registering the next window: [Enforcement.swift, lines 25-32 and 88-102](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/Sources/Shared/Enforcement.swift#L25-L32). It applies and releases all commitment settings through one named store: [lines 31-85](https://github.com/SamuelColacchia/freedomfrom/blob/7425ab3eac403f293fa3dea721499479a2df767f/Sources/Shared/Enforcement.swift#L31-L85). These are implementation observations, not new product decisions.

## Source quality

Apple Developer documentation is primary evidence. Apple Developer Forums were checked only as anecdotal corroboration of uncertainty around multiple schedules and callback reliability; forum reports are not used to settle platform facts.
