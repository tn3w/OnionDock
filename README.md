```
             @@@@@
       @@@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@@   @@@@@
  @@@@@@@@@@@@@@ @@@@@@  @@@@
 @@@@@@@@@@@@@@@@@@  @@@@  @@@   .d88b.       w             888b.            8
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   8P  Y8 8d8b. w .d8b. 8d8b. 8   8 .d8b. .d8b 8.dP
@@@@@@@@@@@@@@@@   @@  @@@  @@@  8b  d8 8P Y8 8 8' .8 8P Y8 8   8 8' .8 8    88b
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   `Y88P' 8   8 8 `Y8P' 8   8 888P' `Y8P' `Y8P 8 Yb
 @@@@@@@@@@@@@@@@@@  @@@@ @@@@   ~- By TN3W: https://github.com/tn3w/OnionDock -~
  @@@@@@@@@@@@@@@@@@@@@  @@@
    @@@@@@@@@@@@@@@   @@@@@
       @@@@@@@@@@@@@@@@@
```

Hardened Tor v3 hidden-service container. Bundles tor + [vanguards](https://github.com/mikeperry-tor/vanguards) (guard/band/rend) + pluggable transports (obfs4, snowflake). Non-root, single Python entrypoint, GPG-verified bundle, SHA-pinned vanguards.

## Quick start

```yaml
services:
    tor:
        image: tn3w/oniondock:latest
        environment:
            SECURITY_LEVEL: high
            TOR_SERVICE_PORTS: '80:webapp:80'
            TOR_TRANSPORT_TYPE: snowflake
        volumes: [./data/hidden_service:/var/lib/tor/hidden_service]
        networks: [onion]
        depends_on: [webapp]
        restart: unless-stopped
    webapp:
        build: ./app
        networks: [onion]
networks: { onion }
```

```
docker compose up -d
docker compose exec tor cat /var/lib/tor/hidden_service/hostname
```

Mounted volume = onion key. Back it up. Lose it → lose the address.

## Configuration

| Env                  | Default        | Values                                  |
| -------------------- | -------------- | --------------------------------------- |
| `SECURITY_LEVEL`     | `high`         | `high` / `medium` / `low`               |
| `TOR_TRANSPORT_TYPE` | `snowflake`    | `snowflake`, `obfs4`, `none`            |
| `TOR_SERVICE_PORTS`  | `80:webapp:80` | `outer:host:inner[,…]`                  |

Custom vanguards: bind-mount `/etc/tor/vanguards.conf` (else upstream defaults).
Encrypted onion key: mount as Docker secret `hs_ed25519_secret_key`.

## Build

```
docker build -t oniondock tor/
docker compose -f example/docker-compose-dev.yml up --build
```

## Architecture

```
[your app] ──(docker net)──► [tor container]
                                ├── tor (alpine)
                                ├── pluggable transports (Tor Expert Bundle, GPG-verified)
                                └── vanguards × {guards, band, rend}
```

- 2-stage build. Builder fetches bundle + clones vanguards; runtime copies only artifacts.
- Bundle GPG-verified against Tor Browser Devs key `EF6E286D…3298290`.
- Vanguards pinned to `c3961ac4…` (v0.3.1). Override: `--build-arg VANGUARDS_SHA=…`.
- One Python entrypoint: render torrc → drop privileges → supervise. No shell.

```
tor/
  Dockerfile      2-stage
  oniondock.py    entrypoint
  config/torrc    hardened template
```

## Security

- Root → `tor` drop verified post-`setuid`; env wiped + rebuilt; `chown` refuses symlinks (`follow_symlinks=False`).
- Port mappings regex + bounds-checked → no torrc injection.
- Bridge selection via `secrets.SystemRandom` (CSPRNG). `iat-mode` forced to `2`.
- torrc disables `SocksPort`/`ORPort`/`DirPort`/`ExitRelay`/`BridgeRelay`/`PublishServerDescriptor` → cannot become a relay.
- `ControlPort 127.0.0.1:9051`, cookie auth, cookie in `/run/tor/` (not in mountable data dir).
- `SafeLogging 1`, `HiddenServiceEnableIntroDoSDefense 1`, `HiddenServicePoWDefensesEnabled 1`, `ConnectionPadding 1`, `CircuitPadding 1`.
- `torrc` written `O_NOFOLLOW` mode `0600`.
- Supervisor exits on _any_ child death → docker restart-policy brings the set back up atomically.
- Healthcheck = TCP probe on control port (catches hung tor).
- Runtime venv has no `pip`/`setuptools`; bytecode precompiled.
- Setuid/setgid bits stripped image-wide. `tor` shell = `/bin/false`.
- Entrypoint + PT binaries + torrc.tmpl + pt_config.json = `0555` / `0444`.
- `STOPSIGNAL SIGTERM`, `PYTHONDONTWRITEBYTECODE=1`, `PYTHONUNBUFFERED=1`.
- Onion key from `/run/secrets/hs_ed25519_secret_key` if present.

## Recommended runtime flags

```yaml
services:
    tor:
        image: tn3w/oniondock:latest
        read_only: true
        tmpfs: [/tmp, /run]
        security_opt: ['no-new-privileges:true']
        cap_drop: [ALL]
        cap_add: [CHOWN, FOWNER, SETUID, SETGID]
        pids_limit: 128
        volumes:
            - tor-data:/var/lib/tor # guard-state persistence
            - ./data/hs:/var/lib/tor/hidden_service
```

Four caps = minimum for chown + setuid. Mounting full `/var/lib/tor` persists guards (otherwise restart → fresh guards → broader exposure).

## Caveats

- Bridges in `pt_config.json` snapshot at build time → rebuild periodically (snowflake unaffected, broker-discovered).
- Tor binary = Alpine pkg, not Tor Project source. Trust chain via Alpine signing.
- `linux/amd64` only (bundle URL hardcoded).
- Vanguards unmaintained since v0.3.1 (Aug 2021).
- Mounted `/var/lib/tor` fingerprints client → treat as sensitive.

## Out of scope

- **Onion key at rest**: tor needs plaintext. Use the Docker-secret hook; encryption boundary = your secrets manager.
- **App-layer DoS**: reverse-proxy/WAF in front of `webapp`.
- **Post-compromise detection**: `cosign verify` before pull + host HIDS after.
- **Sibling-container isolation**: split networks if traffic-volume side-channels matter.

Never expose `webapp`'s port to the host in production.

## CI

GitHub Actions builds + publishes `tn3w/oniondock` on push, signs digests with cosign keyless OIDC.

## License

Apache 2.0 [LICENSE](LICENSE).
