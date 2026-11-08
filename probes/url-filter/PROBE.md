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
| `PIR Server/service-config.json` in the current format | `apple/pir-service-example` commit `f72d3b10` (16 Sep 2026) removed user tiers, and the sample's `users` list makes the server exit with `keyNotFound("tokens")`. Same three tokens, now a flat `tokens` list. The usecase is our extension ID plus `.url.filtering`, as Apple's setup article says |
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
FREEDOMFROM_DEVICE=00008132-001C65641E85001C scripts/mac urlprobe
```

This archives, signs and installs through macbridge, as `scripts/mac probe` does.
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
- [ ] Probe 1. Blocked on the iPad passcode: XCTest asks for it to enable UI
      automation, and enabling the filter asks for it too
