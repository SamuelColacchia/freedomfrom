# URL-filter probe (#83)

Apple's `SimpleURLFilter` sample, vendored to probe the iOS 26 URL filter
(`NEURLFilterManager`) as the way past ManagedSettings' ~50-domain limit (#80).
The research behind the choice is
`docs/research/filtering-past-50-domains-83.md` on `research/83-filtering-past-50`.
Like `probes/filter-capacity`, it is its own app and bundle, so it can't touch
FreedomFrom.

Everything here is Apple's sample except:

| Changed | Why |
|---|---|
| Bundle IDs `com.samuelcolacchia.freedomfrom.urlfilterprobe` and `.extension` | Our identifiers, instead of the sample's team-suffixed `com.example` ones |
| `DEVELOPMENT_TEAM = 6989TSP54U` in all three projects | SwiftBloomFilter is embedded in the app, so it signs with our team too |
| `PIR Server/service-config.json` in the current format | `apple/pir-service-example` commit `f72d3b10` (16 Sep 2026) removed user tiers, and the sample's `users` list makes the server exit with `keyNotFound("tokens")`. Same three tokens, now a flat `tokens` list. The usecase is the **app's** bundle ID plus `.url.filtering`: the device asks for `com.samuelcolacchia.freedomfrom.urlfilterprobe.url.filtering`, and the extension-ID name this file first used made it fail with `NEURLFilterManager.Error` 9 (`serverSetupIncomplete`) |
| `PIR Server/Dockerfile` pins `pir-service-example` to `bbb21535` | The sample cloned it at HEAD, which is how the config broke. `bbb21535` is the commit the running image was built from |

## The server

It runs in Docker Desktop on the Windows PC (192.168.16.200). Windows Firewall
blocks inbound 8080 on that LAN adapter (profile Public), so the iPad reaches it
through the Mac instead:

```
# On the PC (from WSL; docker.exe is Docker Desktop's CLI)
docker build -t pir-server "probes/url-filter/PIR Server"
docker run -d -p 8080:8080 --name pir-server pir-server

# From WSL: tunnel it to the Mac's loopback, and serve it on the Mac's LAN address
ssh -R 18080:127.0.0.1:8080 mac 'python3 -u builds/freedomfrom/pir-forward.py 8080 18080'
```

`pir-forward.py` is a small asyncio TCP forwarder. The Mac's sshd has
`GatewayPorts no`, so a reverse tunnel only binds loopback. The iPad uses
**`http://192.168.16.43:8080`**. Check it from the Mac with
`curl http://192.168.16.43:8080/config`, which should return 200.

Docker Desktop can't bind-mount files from this WSL distro (its WSL integration
is off), so config changes mean rebuilding the image.

## Installing

```
FREEDOMFROM_DEVICE=00008132-001C65641E85001C scripts/mac probe url-filter
```

This archives, signs and installs through macbridge, like the other probes.
On 2026-11-08 it installed on the iPad (iPadOS 27.0.1) with a development
profile carrying `url-filter-provider`, without any request to Apple.

## Probe 1: does it block at all

1. Open SimpleURLFilter, then **Configure**.
2. Set PIR Server URL to `http://192.168.16.43:8080`, leave the Privacy Pass
   issuer empty, set the authentication token to `AAAA`, and turn Enabled on.
   Apply.
3. Approve the prompt with the device passcode, and confirm in Settings.
4. In Safari, load `https://example.com`, which is in the sample's Bloom filter
   and server database. Then load `https://wikipedia.org` as a control.

**Pass:** example.com is refused while wikipedia.org loads, and both load again
once the filter is disabled. Record what each prompt said, and where in Settings
the filter appears.

## Status

- [x] Server built and serving; reachable from the Mac's LAN address
- [x] Probe installed on the iPad, development-signed
- [x] Probe 1, 2026-11-22, iPad (9), iPadOS 27.2.1. See below.

## Probe 1 results, 2026-11-22

iPad (9), iPadOS 27.2.1, development-signed, individual (non-managed) device.
The server ran in Docker on the PC, reached through `pir-forward.py` on the Mac.
WebDriverAgent was running, so no passcode was needed to drive the device.

| Step | Observed |
|---|---|
| Apply with Enabled on | System alert: *"SimpleURLFilter" Would Like to Add URL Filter Configurations. All URL Requests on this iPad may be filtered.* Allow / Don't Allow. After Allow, Settings opened on **VPN** with *Enter iPad Passcode, Add URL Filter Configurations*. A person entered it. |
| First attempt | "Stopped", `NEURLFilterManager.Error` 9 (`serverSetupIncomplete`). The server log said the device asked for usecase `…urlfilterprobe.url.filtering` and the server had only the sample's. Fixed in `service-config.json`; the image was rebuilt with the new config only. |
| Second Apply | "Running". The server served `/config`, `/key`, then `/queries` on each lookup. No second passcode. |
| example.com, filter on | Blocked: Safari's *"Safari can't open the page because it couldn't load any data."* No branded block page. |
| example3.com, filter on | Blocked, same page. |
| wikipedia.org, filter on | Loaded. |
| Disable | "Disabled", one tap in the app, no passcode. |
| example.com, example3.com, filter off | Both loaded. |

So the URL filter does block on an ordinary individual device, from a
development-signed app, with Apple's sample data. It does **not** yet show:

- Anything about scale: the sample's Bloom filter and database hold 10 entries.
- Other browsers or in-app web views.
- What the user sees in Settings to turn it off, or whether that needs the
  passcode. Turning it off from the app needed none.
- Behaviour with the server unreachable (fail-open vs `shouldFailClosed`).
- Distribution: App Store or TestFlight signing for `url-filter-provider`.

## Probe 2 results, 2026-11-22: 5000 domains, Chrome, server down

Same iPad and setup as probe 1. Row tables are in `results/20261122/`; each
row was scored from its own UI tree and address, and the trees and screenshots
stay off the repo because they show the device's own browser tabs.

**The list.** `lists-5000.txt` is Tranco ranks 2001-7155 (list `46YLX`,
fetched 2026-11-22) with 155 Apple, Google, Microsoft, CDN and tooling hosts
left out so the device and harness keep working. `make-lists.ts` turns it
into the extension's Bloom filter and the server's PIR database; its
`--check` reproduces the sample's shipped filter bit for bit. Controls came
from ranks 7156-10155, so none is listed.

**Scoring.** Safari's block page reads *"Safari can't open the page because it
couldn't load any data."* with a **non-breaking space** before "data"; a
pattern with a plain space scored the first block `failed`, caught on the
fixture check before any sweep ran. Chrome's is *"This site can't be reached"*
with `ERR_INSUFFICIENT_RESOURCES`. Each sweep was preceded by a blocked,
a loaded and a failed fixture scoring correctly.

| Sweep | Rows | Result |
|---|---|---|
| `safari-on` | 20 listed, 2 `www.` forms of listed bare domains, 10 controls | 22/22 blocked, 10/10 loaded |
| `chrome-on` | same 32, typed into Chrome's address bar | 22/22 blocked, 10/10 loaded |
| `safari-server-down-failopen` | server stopped, `shouldFailClosed` off: 6 listed never looked up, 3 listed looked up earlier, 2 controls | 6/6 never-seen listed **loaded**; 3/3 seen listed blocked; 2/2 controls loaded |
| `safari-server-down-failclosed` | server stopped, Fail Closed on (read back as `value: 1`): 5 listed never looked up, 3 controls | 5/5 blocked, 3/3 loaded |
| `safari-off` | filter disabled: every host blocked above | 27/27 loaded, so no block was a network failure |

What this shows, on this device and iOS only:

- 5000 entries filter correctly, with no visible slowdown. Nothing here bounds
  the ceiling; Apple's documentation speaks of millions.
- Chrome is covered the same as Safari, with its own error page.
- A listed bare domain also blocks its `www.` form (2 of 2).
- With the server unreachable, the default **fails open**: a listed site the
  device has not asked about before loads. Answers already received are cached
  and keep blocking. Fail Closed blocks listed sites with the server down, and
  only sites that hit the Bloom filter need the server at all, so unlisted
  sites still load.
- Turning Fail Closed on needed no passcode, only Apply with the server up.

Still open: other browsers and in-app web views, how long cached answers last,
the Settings path to turn the filter off, and distribution signing.
