# Commitment timer: DeviceActivity mechanics, reliability, and failure modes

## Bottom line

A `DeviceActivitySchedule` is calendar-based, not a monotonic timer. Apple documents `repeats`, and the schedule APIs allow a non-repeating interval, but they also cap monitoring at **15 minutes minimum** and **one week maximum**. So: **yes, a one-shot block is expressible only when the interval is between 15 minutes and 1 week**; **30 days is not**. [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule) · [intervalTooShort](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort) · [intervalTooLong](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltoolong)

Apple also says `intervalDidStart` / `intervalDidEnd` only fire **when the device is in use**. That means the API is best treated as a **best-effort wakeup**, not an exact alarm. [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter) · [intervalDidStart](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:)) · [intervalDidEnd](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))

## Safe v1 design

1. Store the commitment deadline as an absolute wall-clock `Date` in App Group storage.
2. Start a **non-repeating** `DeviceActivitySchedule` for the shortest legal interval that reaches that deadline.
3. In the monitor extension, treat every callback as a chance to reconcile: if `Date() >= deadline`, clear the shield and delete the commitment state; otherwise leave it alone.
4. On app launch / foreground, run the same reconciliation so stale shields self-heal even if the extension was missed.
5. Keep all shield mutations in one named `ManagedSettingsStore` and make the extension read only a small shared snapshot.

That makes DeviceActivity the watchdog, not the sole source of truth.

## Failure modes v1 must handle

- **Interval too short**: monitoring under 15 minutes throws `intervalTooShort`. [intervalTooShort](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)
- **Interval too long**: monitoring over one week throws `intervalTooLong`. [intervalTooLong](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltoolong)
- **No device use at expiry**: callbacks are deferred until the next device use. Apple documents this explicitly. [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter)
- **Extension launch failures / jetsam**: forum reports show intermittent launch failures, invalid plugin paths, and a very small per-process memory ceiling (~6 MB). [Forum 745035](https://developer.apple.com/forums/thread/745035) · [Forum 827783](https://developer.apple.com/forums/thread/827783) · [Forum 756959](https://developer.apple.com/forums/thread/756959)
- **`intervalDidStart` / `intervalDidEnd` not firing**: multiple forum reports describe schedules that register successfully but never wake the extension. [Forum 819224](https://developer.apple.com/forums/thread/819224) · [Forum 826133](https://developer.apple.com/forums/thread/826133)
- **`eventDidReachThreshold` misfires immediately**: iOS 26-era regressions report immediate threshold firing, including with `includesPastActivity = false`. [Forum 808470](https://developer.apple.com/forums/thread/808470) · [Forum 809410](https://developer.apple.com/forums/thread/809410) · [Forum 819997](https://developer.apple.com/forums/thread/819997)
- **Clock manipulation**: the API is calendar-based. Apple does not provide a public API to detect that the user manually changed device time, so wall-clock changes remain a bypass vector. [startMonitoring(_:during:events:)](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:)) · [How to know if device time is altered by user](https://developer.apple.com/forums/thread/730565)
- **Time-zone changes**: Apple says time-zone changes affect how ongoing events are calculated. [startMonitoring(_:during:events:)](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:))
- **Shared-state lag**: `UserDefaults` propagation is asynchronous; `synchronize()` is a no-op. [Forum 728044](https://developer.apple.com/forums/thread/728044)
- **Token mismatch / randomization**: persisted `ApplicationToken` / `WebDomainToken` values can become stale or mismatched in practice. [Forum 758325](https://developer.apple.com/forums/thread/758325) · [Forum 814571](https://developer.apple.com/forums/thread/814571)
- **App force-quit / never reopened**: the app-side recovery pass will not run, so the monitor extension must be able to reconcile on its own. If the blocker app is also shielded, the user can strand the system. Do not shield the management app.
- **Device restart mid-interval**: forum reports say a restart sometimes helps and sometimes does not; there is no Apple guarantee that a restart replays a missed callback.

## What Apple guarantees

- `DeviceActivitySchedule` is calendar-based and can recur or not recur. [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule)
- `startMonitoring` starts monitoring a schedule and optional events; an empty event map means only schedule start/end callbacks. [startMonitoring(_:during:events:)](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:))
- `intervalDidStart` fires when someone first uses the device within the interval. [intervalDidStart](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:))
- `intervalDidEnd` fires when someone first uses the device outside the interval, or when monitoring is stopped while an interval is ongoing. [intervalDidEnd](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))
- `ManagedSettingsStore` named stores are shared between the app and its extensions. WWDC22 called that out explicitly. [WWDC22 110336](https://developer.apple.com/videos/play/wwdc2022/110336/)

## What practitioners do

Real projects tend to:

- keep the extension tiny,
- store only a small config blob in App Group storage,
- use a named `ManagedSettingsStore`,
- re-clear shields in `intervalDidEnd`, and
- add wall-clock guards against spurious callbacks.

Examples:

- `ScreenTime_Barebones` applies shields in `intervalDidStart` and calls `clearAllSettings()` in `intervalDidEnd`. [GitHub permalink](https://github.com/CoffeeNaeriRei/ScreenTime_Barebones/blob/c8f78d68d7677ab7c75e06a27e9dd849f717e5ed/DeviceActivityMonitor/DeviceActivityMonitorExtension.swift#L14-L41)
- `expo-app-blocker` keeps unlock state in App Group `UserDefaults` and ignores obviously spurious threshold fires by comparing elapsed wall-clock time to the granted budget. [GitHub permalink](https://github.com/eylonshm/expo-app-blocker/blob/f9bc0c4e8d9fc6befbbf3d2d044f57a77c51dc17/targets/DeviceActivityMonitor/DeviceActivityMonitor.swift#L29-L92)

## Token durability

Apple documents `FamilyActivitySelection` tokens as **opaque values**. They can be passed to Managed Settings / Device Activity, and `Token<T>` is `Codable` / `Equatable`, so persisting them is normal. But Apple does **not** promise long-term semantic stability in the docs I found, and forum reports show real-world token churn/mismatch after OS changes. Treat persisted tokens as a cache, not as a durable identity. [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection) · [Forum 758325](https://developer.apple.com/forums/thread/758325) · [Forum 814571](https://developer.apple.com/forums/thread/814571)

## Could not confirm

- A device-activity-specific API to detect manual clock changes.
- A guaranteed way to force `intervalDidEnd` to run on a powered-off or idle device.
- A supported Keychain-access-group pattern for sharing monitor state with the extension.
- A distinct Low Power Mode contract for DeviceActivity beyond the general “device in use” guarantee.

The docs and reports I found point to App Group storage + tiny snapshots, but not to a stronger first-party state channel.
