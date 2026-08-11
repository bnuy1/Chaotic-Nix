# Bnuyhole Home-Lab Plan

Status tracking for the home-lab network. **Current focus: Pterodactyl panel + Wings + Minecraft domain forwarding.**

## Architecture (two tiers)

| Tier | Services | Path to clients | TLS |
|---|---|---|---|
| **Private** | Pterodactyl panel + Wings | WireGuard (remote) or LAN, direct to `192.168.2.3` | **E2E** — local `step-ca` CA, no third party |
| **Public** | Minecraft proxy (Velocity/Geyser) | Direct TCP 25565 + UDP 19132, grey-cloud DNS | MC's own protocol encryption; no Cloudflare in path |
| **Public** | Panel over WAN | Cloudflare Tunnel (outbound), proxied | **HTTPS on BOTH legs** (client→CF + CF→origin) |

**Decisions (agreed):**
- **HTTPS everywhere** — LAN/WireGuard access uses a local `step-ca` cert for `192.168.2.3`; WAN access to the panel goes through the Cloudflare tunnel with **Full (strict)** so both legs (client→CF and CF→origin) are HTTPS, origin validated by a real Let's Encrypt cert for `minecraft.bnuy.dev`.
- Minecraft public via direct port-forwards + grey-cloud DNS (no Cloudflare in path; MC is not HTTP, free Cloudflare can't carry it — Spectrum is paid).
- Local CA = `step-ca` on singularity for offline-safe HTTPS (works when internet is out).
- Router only forwards specific ports; **443/80 are blocked inbound** → panel WAN access uses Cloudflare Tunnel (outbound).

---

## Part 1 — FOCUS: Pterodactyl Panel + Wings

### Current state (2026-08-06)

- Panel runs on singularity (`192.168.2.3`), nginx + php-fpm + mariadb + redis, all healthy.
- **Blank-white-screen bug: FIXED.** `/srv/pterodactyl` had mode `0700`; nginx (group `pterodactyl`) could not traverse it, so every `/assets/*.js` request fell through `try_files` to `index.php` and returned HTML → browser JS parse error → blank page. `chmod 750 /srv/pterodactyl` fixed it; the NixOS module already enforces 0750 via tmpfiles + adds nginx to the pterodactyl group. **Note: something re-chmod'd it to 0700 after boot — root cause still unknown; watch for recurrence.**
- **step-ca: DONE.** Local CA `Bnuyhole Home Lab CA` runs on singularity as the `step-ca` system user (nixpkgs `services.step-ca` module, `DynamicUser` disabled so `/var/lib/step-ca` stays directly accessible). Root fingerprint `2d802436...3aa8`, root CA in the system trust store, CA password in SOPS (`step-ca/password`). Leaf cert `CN=192.168.2.3` (issuer Bnuyhole Intermediate CA) installed at `/var/lib/pterodactyl/ssl/{cert,key}.pem`, served by nginx (LAN vhost) and Wings' own API on 8080.
- **Wings: RUNNING.** Config generated via `wings configure`; ownership fixed (`pterodactyl:pterodactyl` 600); unit gained `StateDirectory/LogsDirectory/RuntimeDirectory` so it works under `ProtectSystem=strict`. Wings connects to the panel at `https://192.168.2.3` (validated against the trust store — no cert errors), serves its API on `0.0.0.0:8080` with the step-ca cert, SFTP on 2022, `pterodactyl0` bridge up.
- **Panel node:** FQDN `192.168.2.3`, scheme https, daemonListen 8080 (panel→Wings = `https://192.168.2.3:8080`, TLS validated).
- nginx serves the step-ca cert for the LAN vhost `192.168.2.3` (443/8443, default) and the Let's Encrypt cert for `minecraft.bnuy.dev` (443/8443) as the Cloudflare origin (Full-strict). `APP_URL=https://minecraft.bnuy.dev`.

### The panel domain problem

- ~~Panel is configured for hostname `minecraft.bnuy.dev` but accessed at the IP → cert mismatch.~~ **Resolved**: nginx now serves a step-ca cert valid for `192.168.2.3` on the LAN vhost; install the root CA once on devices and `https://192.168.2.3` has no warnings.
- WAN access keeps `minecraft.bnuy.dev` via the tunnel (Full-strict, both legs HTTPS).

### Panel plan

1. **Short term — DONE**
   - Cert valid for `192.168.2.3` (step-ca, trusted root). 
2. **Proper fix — `step-ca` local CA — DONE**
   - `services.step-ca` (nixpkgs module) on singularity, non-root; leaf SAN `192.168.2.3` (add `10.0.0.1` once WG exists); CA password in SOPS.
   - Clients install `root_ca.crt` once → no warnings, certs auto-renew **locally** so HTTPS survives internet outages.
3. **Remaining hardening**
   - Restrict Wings API (8080) / SFTP (2022) to localhost/LAN.
   - Keep the Cloudflare tunnel for WAN access; set Cloudflare **Full (strict)** so the origin's LE cert is verified (client→CF and CF→origin both HTTPS).

### Wings setup — DONE

- `/etc/pterodactyl/config.yml` generated via the panel's Auto Deploy (`wings configure`); the module's `pterodactyl-wings-gamesdir` service points `system.data` at `/games/pterodactyl` and enforces cert perms each boot.
- Wings unit runs as `pterodactyl` with `ProtectSystem=strict` + `StateDirectory/LogsDirectory/RuntimeDirectory` (pterodactyl, pterodactyl, wings).
- Wings validates the panel at `https://192.168.2.3` against the system trust store (step-ca root) — no `--ignore-certificate-errors` needed.

---

## Part 2 — Minecraft domain forwarding (`bnuy.dev`)

Goal: friends type **`bnuy.dev`** in the Minecraft server bar and join.

### Status

- **Minecraft runs as Wings-managed game servers in the Pterodactyl panel** (NOT the docker `modules/development/minecraft-server` module — that one is orphaned/unused).
- **DNS: DONE.** `bnuy.dev`, `play.bnuy.dev`, `minecraft.bnuy.dev` all resolve (grey-cloud, DNS-only) to home WAN IP `70.22.183.131`. No Cloudflare proxying in the MC path.
- **Panel login: reset.** `bnuy` admin password reset to a temp password (2026-08-06); panel at `https://192.168.2.3`.
- **Wings: connected.** Node 1 = FQDN `192.168.2.3`, https, port 8080; Wings online and talking to the panel.
- **Router (user action):** forward TCP `25565` → `192.168.2.3` and UDP `19132` → `192.168.2.3`. Ports 25565/19132 are not in the router's blocked list. Confirm no CGNAT.

### To do

1. Create Velocity proxy server (port 25565) + Paper backends in the panel; Wings serves them.
2. Router: TCP 25565 + UDP 19132 → `192.168.2.3`; verify no CGNAT.
3. Cloudflare: set the `minecraft.bnuy.dev` tunnel to **Full (strict)** (HTTPS both legs; origin already serves the LE cert).
4. Install the step-ca root CA on client devices to silence `https://192.168.2.3` warnings.

---

## Part 3 — Documented, not under active discussion

- **WireGuard (`services.vpn`)** — enable on singularity (`10.0.0.1/24`), forward UDP `51820`; clients route `10.0.0.0/24` + `192.168.2.0/24` so the panel is always reached at `https://192.168.2.3`.
- **Future website** — `services.cloudflared.tunnels` (nixpkgs module) mapping `bnuy.dev` → local site; proxied CNAME; Cloudflare free Universal SSL + caching/WAF.
- **Technitium DNS** — module exists (`services.technitium`), currently auto-enabled by the pterodactyl module (`configureDNS`); used for LAN `.local` resolution; revisit for split-DNS.
- **Namecheap** — registrar only; nameservers point at Cloudflare (verify if not done).
- **Remote backups** — `remote-mc-backup` rsyncs `/var/backups/minecraft` → `mcbackup.bnuy.dev` over SSH port `vars.rsyncPort`.

---

## Open actions / checklist

- [x] Fix blank white screen (0700 → 0750 on `/srv/pterodactyl`)
- [x] Write plan.md
- [x] Reset `bnuy` panel password (temp: communicated in chat)
- [x] Create Node in panel + run Wings auto-deploy (generates `config.yml`)
- [x] Set up `step-ca` (nixpkgs module, non-root); issue cert for `192.168.2.3`; trust root system-wide
- [x] Get Wings running (config.yml perms + hardened unit dirs)
- [ ] Find out what re-chmod'd `/srv/pterodactyl` to 0700 (durability)
- [ ] Router: forward TCP 25565 + UDP 19132 (Minecraft); verify no CGNAT
- [ ] Create Velocity (25565) + Paper servers in panel under Wings
- [ ] Cloudflare: proxy `minecraft.bnuy.dev` to the tunnel (orange cloud) + set TLS mode **Full (strict)** for HTTPS on both legs
- [ ] Install step-ca root on client devices (no warning at `https://192.168.2.3`)
- [ ] Restrict Wings API (8080) / SFTP (2022) to localhost/LAN
