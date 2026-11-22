# The URL filter's lookup server

The PIR server from `../PIR Server`, behind Caddy, as a plain Docker Compose
stack anyone can run. It is what the iOS URL filter asks when a site hits the
on-device Bloom filter.

## What runs where

| Piece | Where | Notes |
|---|---|---|
| `service.freedomfrom.app` | Cloudflare DNS, **DNS-only** A record | Not proxied, so Caddy gets its own certificate and the server sees connections directly |
| Droplet `freedomfrom-pir-1` | DigitalOcean `sfo3`, `s-1vcpu-1gb`, Ubuntu 24.04 | About $6/month. `ufw` allows 22, 80 and 443 |
| `caddy` | `caddy:2`, ports 80 and 443 | Let's Encrypt certificate, HTTP/2 |
| `pir` | `freedomfrom-pir:<tag>`, internal port 8080 only | Built from `../PIR Server` with today's list |

The user bearer token is in `service-config.json` on the server and in
`~/.config/freedomfrom/pir-token` on the machine that deploys. It never enters
the repo.

## Deploying

```sh
probes/url-filter/server/deploy root@<ip>          # PIR only
probes/url-filter/server/deploy root@<ip> --tls    # PIR behind Caddy
```

From WSL, set `DOCKER` to Docker Desktop's `docker.exe`. The image is built
locally and shipped, because compiling the Swift service needs more memory than
the Droplet has. Every step runs over one multiplexed ssh connection: a burst of
separate connections had port 22 dropped mid-deploy on 2026-11-22, and only a
reboot from the DigitalOcean API brought it back. The cause was not found.

## Load

Lookups happen only for Bloom-filter hits, and the device caches each answer.

| Host | Database | Server time per lookup |
|---|---|---|
| Windows PC (Docker Desktop) | 5000 entries, one 845 KB shard | 21 ms median, 29 ms max (32 lookups) |
| This Droplet, 1 vCPU | same | 62-99 ms (6 lookups) |

## Not production yet

What Apple requires before a TestFlight or App Store build can use it
(`docs/research/url-filter-production-requirements.md`):

- An OHTTP gateway on its own subdomain; Apple's relay forwards every lookup to it.
- A Privacy Pass issuer that persists its keys. The example server keeps them in
  memory, so every restart invalidates tokens already issued.
- Registration in CloudKit Console, Identity & Trust, with the DNS TXT record
  `apple-url-filter=<app bundle id>` and Apple's test entry
  `www.apple.com/url-filter-test` in the database.
- Apple's own warning that the example service "should not be run in production".
