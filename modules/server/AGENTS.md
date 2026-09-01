# AGENTS.md — bnuynix security intent + plan

This file is the contract for every security-relevant change to this repo. It
documents the operator's threat model, the agreed posture, and the concrete
backlog derived from the 2026-08-28 audit. Any change that contradicts a rule
below needs a `# ponytail:` comment AND a CHANGES.md entry — per repo styleguide.
The styleguide at `~/.config/opencode/rules/styleguide.md` always wins on style.

## Threat model

- **Singularity is a DMZ box at the router level.** The WAN edge (router
  port-forwards, the Cloudflare tunnel ingress, DNS records) is hostile. The
  only trusted zones are LAN subnets `192.168.1.0/24` + `192.168.2.0/24` and
  the bnuy tailnet (`100.64.0.0/10`).
- **Tailnet tiers** (headscale ACL, `modules/server/vpn/headscale.nix`):
  `bnuy@`/`admin@`/`tag:admin` = everything; `staff@` = service ports only;
  `guest@` = view-only web (443) + DNS (53). ATTENTION: the operator intends to
  tighten guest tier — see plan item G.
- **Allowed public surface** (do not extend without a deliberate, commented
  decision): tunneled web UIs `dash/kuma/ntfy/password/mail.bnuy.dev`, mail
  protocols on `mx.bnuy.dev` (25/465/587/993/995/4190), `mc.bnuy.dev:25565`,
  `vpn.bnuy.dev:8443` (headscale control plane + DERP). Everything else is
  LAN/tailnet by default.
- **Identity**: where cheap, mailcow = the source of truth (mailbox list →
  other systems' account lists). Never hardcode credentials; sops only.
- **RAM budget**: 16 GB box. Prefer the lightest component that meets the goal;
  1 GB for a single service (Authentik) is only acceptable if nothing lighter
  works.

## Posture rules (non-negotiable unless overridden above)

1. **No default passwords anywhere.** `initialPassword = "password"` is a
   critical-hole class bug. Accounts authenticate by SSH key; a Unix/console
   password is set out-of-band (sops `hashedPassword`) or not at all.
2. **A login page is not exposure for a public service.** Apps with their own
   auth (mailcow webmail, vaultwarden, uptime-kuma, ntfy) may stay public with
   app-level auth + rate limiting. An SSO/forward-auth gate is for apps with
   NO login wall (homepage) and for edge rate-limiting/abuse control — NOT a
   second prompt in front of an existing login.
3. **Admin/API surfaces are LAN + tailnet only** via `tls.vpnLanFence`
   (`modules/server/lib.nix`), even when the app UI must be public. This is
   already done for `mailcow /admin`; `/api/v1` must join it.
4. **Docker-published ports are NOT covered by the nixos-fw INPUT chain**
   (they DNAT + FORWARD). WAN-restricting a docker-published port requires
   iptables rules in the `DOCKER-USER` chain, not `networking.firewall.*`.
5. **The 443 `default_server` must never be a real app.** Unknown Host headers
   (incl. the tunnel origin dialing localhost) fall through to it; it must be a
   deny/444 stub or a fenced vhost.
6. **Guest tier gets no LAN namespace disclosure.** Guests may need DNS for
   MagicDNS (`nameservers.global = 192.168.2.3` is pushed to all tiers), but the
   Technitium internal `network` zone + split-DNS zones must not enumerate our
   topology to them.
7. **sops everywhere.** Every credential in `modules/**/secrets.yaml`,
   encrypted with the steps in `modules/server/.sops.yaml`. No plaintext
   secrets, no loose token files in the tree.
8. **Per-service least privilege**: service users, group-scoped ACLs, folder
   passwords for syncthing, UID-scoped restic repos (never 0777).

## Decision log (from the 2026-08-28 audit + operator replies)

- **Homepage (H1):** becomes the GUEST landing page (`dash.bnuy.dev`): tiles
  for friend-facing services only (jellyfin, immich, ...); management apps are
  NOT advertised there. bnuy's auto-login comes from a trusted-source bypass
  at nginx (explicit bnuy tailnet IPs + LAN subnets) + authentik session
  cookies off-VPN. NEVER bypass on the whole `100.64.0.0/10` — tailnet guests
  share it and would clear every login wall.
- **Authentik (IdP):** CHOSEN for identity + nginx forward-auth. Postgres-only
  since 2025.10 (no Redis). MUST pin >= 2026.2.3 / 2025.12.5: GHSA-5wcc-hf24-rf5h
  (critical nginx forward-auth bypass via client-injected `X-Original-URI`);
  the outpost location must also overwrite that header itself. Hosted at
  `auth.bnuy.dev` (tunneled, public — login redirects must reach guest
  cellular; never behind CF Access). Guests get NO authentik accounts — the
  landing page is plain public, guest apps use their own auth, and only bnuy
  ever sees an authentik login (mgmt tiles + future mailbox login).
- **DNS naming (2026-08-30):** the internal `*.network` zone dies → real
  `*.bnuy.dev` subdomains (`technitium.bnuy.dev`, `mailcow.bnuy.dev`,
  `pterodactyl.bnuy.dev`, `vpn.bnuy.dev` for the headscale LAN panel —
  control-plane/derp port 8443 stays public on the same name). External
  visitors to those hostnames get a styled HTML 403 landing (operator-created)
  served by the fenced vhosts through the tunnel.
- **IdP/landing architecture (2026-08-30):** ONE homepage instance
  (`dash.bnuy.dev`, public): friend-facing tiles for guests; a `management`
  group/box for bnuy only, gated by the authentik forward-auth outpost — guests
  never see those tiles and never hit an authentik login screen. Authentik
  confirmed at `auth.bnuy.dev`, tunneled + public, not behind CF Access.
- **Vaultwarden (H2):** prefer provisioning accounts from the mailcow mailbox
  list (admin API sync timer). If that proves infeasible, `signupsAllowed = false`
  permanently.
- **Syncthing (H3):** gate port 8384/22000 to bnuy's tailnet IP + LAN only;
  GUI + Projects + Documents get sops-managed passwords. `secrets.yaml.example`
  must be created.
- **Mailcow (M1):** `/admin` AND `/api/v1` fenced LAN/tailnet. Cleartext
  110/143 blocked from WAN via DOCKER-USER. Domain-admin UI stays LAN/tailnet.
- **Pterodactyl (M2/M3):** LAN vhost + wings proxy + SFTP fenced because the
  box is a DMZ. 443 default_server retired to a deny stub.
- **Technitium (G/M4):** fix guest-tier DNS disclosure (plan item G).
- **Low/hygiene (L1–L5):** all to be fixed (plan item L).
- **Users (P-a, 2026-08-30):** operator confirmed removing both
  `initialPassword = "password"` lines needs no other change: the bootstrap
  password was not the live sudo loop, and `admin` is a console-only fallback
  with no external access (no SSH key).
- **Identities:** mailcow mailbox creds = the preferred "sign in" source where
  achievable without a heavy IdP.
- **Authentik deployment (2026-08-31):** `modules/server/authentik` (greenfield
  `services.authentik` = authentik 2026.8 via docker compose) deployed + healthy
  on singularity, public vhost `auth.bnuy.dev` (tunneled, NOT behind CF Access).
  Core is live and the `/setup` first-run page serves. Remaining interactive
  work is browser-owned: admin bootstrap, mailcow OAuth2/OIDC **source**
  (mailcow = IdP, live mailbox passwords — fixes adriannascarr), Proxy
  provider/Outpost at 127.0.0.1:9000, then `forwardAuth` on the headscale panel
  vhost + homepage `management` group. ONLY apps with no native login wall get
  forward-auth (posture rule 2). Details in `authentik/CHANGES.md`.
- **`mkTlsApp` bug fix (2026-08-31):** `modules/server/lib.nix` `mkTlsApp`
  used a shallow `//`, letting `mkAcme` REPLACE `mkCertSync`'s `systemd` key and
  silently drop the `<name>-cert` sync service for every mkTlsApp vhost
  (homepage/ntfy/kuma/authentik). Fixed with `lib.recursiveUpdate`; all 4 hosts
  pass `nix flake check`.

## Backlog (follow these for the fixes)

Status legend: `[ ]` open · `[~]` in progress · `[x]` done.

- **P-a. Remove all default passwords** `[x]`
  - Delete `users.users.admin.initialPassword = "password";`
    (`hosts/singularity/default.nix:207`).
  - Delete `initialPassword = "password";` from the bnuy entry
    (`hosts/singularity/variables.nix:25`); the consumer at
    `modules/core/home_manager.nix:45-46` already skips a null.
  - `admin` fallback gets NO ssh key and NO password (operator 2026-08-30:
    "no external access") — local console/out-of-band only. bnuy's ssh keys
    and sudo are untouched; the bootstrap password was never the live loop.
- **P-b. Vaultwarden user provisioning from mailcow** `[x]`
  - `[x]` `SIGNUPS_ALLOWED=false` enforced again (host sets `services.vaultwarden.mailcowSync = true;`; signups off by default).
  - `[x]` Reconcile timer `vaultwarden-mailcow-sync` on the verified `/admin`
    cookie flow: `POST /admin` (raw token) → `VW_ADMIN` cookie → reconcile via
    `GET /admin/users`, `POST /admin/invite`, `POST /admin/users/<id>/disable`.
    New sops secret `vaultwarden/admin_raw_token` (raw login secret); the argon2
    hash in `admin_token` only backs the daemon login. Daemon switched to the
    new token pair 2026-08-31; live-verified one run (invited a missing active
    mailbox). DB kept (operator: no wipe). FULL notes in `vaultwarden/CHANGES.md`.
- **P-c. Syncthing auth + scope** `[x]`
  - `[x]` GUI auth wired: `guiPasswordFile` ← sops `syncthing/gui_password`
    (runtime bcrypt via the nixpkgs module's REST PATCH), `settings.gui.user =
    "bnuy"`, sops ordering on `syncthing-init`, `secrets.yaml.example` created.
  - `[x]` FOLDER-PASSWORD DEVIATION (ponytail): settings.folders.<id>.password
    is plaintext-baked into the nix store by the nixpkgs module (rule 7
    violation) with no file-backed mechanism — left unset, set in the GUI
    out-of-band; they must match on every device of the folder anyway.
  - `[x]` tailnet-IP gating: resolved MOOT (2026-08-31) — the phone syncs
    over its own cleartext path, not the tailnet, so pinning the
    whole-tailscale0 iptables rules (`syncthing.nix`) to one IP adds nothing.
    Rules stay as-is; comment updated. Open item 3 closed.
- **P-d. Mailcow fence `/api/v1`** `[x]`
  - Add a `locations."/api/v1"` block identical to `/admin`
    (`mailserver.nix:258-270`) with `${tls.vpnLanFence}`. Webmail/CalDAV never
    touch it; only admin tooling does, and that is LAN/tailnet now.
  - NOTE: on-box tooling (`mailcow-provision`, future P-b sync) curls the
    loopback `httpsPort` directly, so the fence only cuts cross-WAN /api/v1.
- **P-e. DNS hygiene (L3 + G)** `[~]`
  - `[x]` Guest-tier disclosure: drop `53` from `acl.guestPorts` (`headscale.nix`),
    disable guest MagicDNS push — guest devices fall back to their own
    resolution (technitium zone-source locking not viable).
  - `[ ]` Enable DNSSEC validation locally: `services.resolved.settings.Resolve.DNSSEC
= true` (technitium validates upstream; the LAN leg stays cleartext —
    documented DNS-01/LE dependency). NOTE: currently `lib.mkIf cfg.useLocally
    false` with a ponytail comment — enabling outright breaks unsigned local
    `* .network` zones until the P-e DNS migration to `*.bnuy.dev` runs.
- **P-f. Pterodactyl + 443 default fence (M2/M3)** `[x]`
  - `[x]` `${tls.vpnLanFence}` on the LAN panel vhosts (domain + listenIP) and
    the wings proxy (`pterodactyl.nix`).
  - `[x]` `default = true` moved off the listenIP vhost → dedicated 444 default
    stub on 443 (SSL, lanCert), unmatched Host/SNI → connection close.
  - `[x]` `wingsProxyPort` (8084) + `wingsSftpPort` (2022) removed from
    `allowedTCPPorts`; source-scoped ACCEPTs prepended `-I INPUT 1` for LAN
    subnets + tailnet in `networking.firewall.extraCommands` (default DROP
    handles the rest).
  - `[x]` wings config.yml `allowed_origins` sed switched to `${cfg.domain}
    ` (was hardcoded `https://pterodactyl.network`).
- **P-g. Cleartext mail ports (L1)** `[x]`
  - Keep 25/465/587/993/995/4190 (required for MX + submission), but block 110
    and 143 globally via DOCKER-USER RETURN-for-trusted then DROP
    (docker-published ports ignore `networking.firewall.*`; postfix/dovecot
    already enforce TLS inbound). NOTE: rules are emitted one `--dport` per
    rule — this kernel ships no xt_multiport, so `-m multiport` fails
    (nft_compat can't translate it).
  - IMPLEMENTED as `mailcow-docker-user-fence` (writeShellScript) hooked on
    `systemd.services.docker.postStart` so it re-asserts on every docker
    start (docker recreates DOCKER-USER).
- **P-h. Restic repo perms (L4)** `[x]`
  - `modules/server/pterodactyl/pterodactyl.nix`: 0777 → 0770
    `root:pterodactyl` (the mc-backup containers run as uid 994 =
    pterodactyl).
  - IMPLEMENTED (2026-08-30): `systemd.tmpfiles.rules` uses
    `d ... 0770 root pterodactyl -` PLUS a `Z ... 0770 root pterodactyl -`
    line per repo so already-created 0777 dirs get re-chowned/re-modded on the
    next boot.
- **P-i. Remove loose token from the tree (L2)** `[x]`
  - `modules/server/secret` (untracked) — plaintext Cloudflare tunnel token
    JSON. DELETED (2026-08-30); operator rerolls the tunnel token anyway
    ("ill have to reroll it anyways").
- **P-j. Homepage edge hardening** `[~]`
  - `[x]` nginx `limit_req` zone `bnuy_public` (10r/s, burst 25) on the public
    vhosts (homepage, uptime-kuma, ntfy, vaultwarden, mailcow), keyed by
    `$http_cf_connecting_ip` (tunnel origin is 127.0.0.1; CF edge overwrites
    that header so it can't be spoofed), via
    `services.nginx.commonHttpConfig`.
  - `[ ]` Evaluate oauth2-proxy → mailcow OAuth2 forward-auth for homepage
    below (deferred — needs authentik/rollout session).

## Execution notes (session state 2026-08-30, restart as sudo)

The operator restarts this session with sudo to rebuild/verify. This section is
the handoff so work continues without re-deriving decisions. The git tree has
LOTS of unrelated staged WIP from the operator's earlier dev sessions — DO NOT
`git commit` anything unless explicitly asked, and stage only the files this
plan touches.

### Decisions locked this session (recommended = chosen)

- Single homepage instance at `dash.bnuy.dev`; bnuy-only `management` group
  gated by the authentik outpost; guests get NO authentik accounts.
- Headscale LAN panel → `vpn.bnuy.dev` (fenced vhost; 8443 control-plane/derp
  stays public on the same name). DNS migration hostnames: `technitium.bnuy.dev`,
  `mailcow.bnuy.dev`, `pterodactyl.bnuy.dev`.
- Authentik IdP host `auth.bnuy.dev` (tunneled, public, NEVER behind CF Access);
  pin >= 2026.2.3 / 2025.12.5 (GHSA-5wcc-hf24-rf5h).
- P-a: both `initialPassword = "password"` lines removed; `admin` keeps NO ssh
  key and NO password (console-only fallback, operator: "no external access").

### Done this session (verified via `nix eval`; NOT yet built/rebuilt)

- P-a (default passwords) — evals show initialPassword = null for admin+bnuy,
  admin has 0 ssh keys.
- P-d (/api/v1 fence) + P-g (DOCKER-USER 110/143 fence) — applied in
  `modules/server/mailserver/mailserver.nix`; `mailserver/CHANGES.md` created.
  The DOCKER-USER fence is `mailcow-docker-user-fence` hooked on
  `systemd.services.docker.execStartPost` (re-asserts on docker restarts).
- P-f (pterodactyl LAN fence + 444 default vhost + wings 8084/2022 scoped) +
  P-h (restic repos 0770): applied in `modules/server/pterodactyl/pterodactyl.nix`.
- P-e guest disclosure: `acl.guestPorts` default now `[ 443 ]`
  (`vpn/headscale.nix`), host sets `guestPorts = [ 443 ]`; guest MagicDNS push
  dropped. resolved DNSSEC stays false (ponytail note in technitium.nix) until
  the `*.bnuy.dev` migration.
- P-b: signups forced off, `vaultwarden-mailcow-sync` reconcile timer rewritten
  to the `/admin` cookie flow (raw `admin_raw_token` → `VW_ADMIN` cookie →
  `GET /admin/users`, `POST /admin/invite`, `POST /admin/users/<id>/disable`)
  and ENABLED (`mailcowSync = true`); daemon switched to the new
  admin_token/admin_raw_token pair. Live-verified one run 2026-08-31: invited
  the missing active `adriannascarr@bnuy.dev` mailbox; fixed `.active == "1"`
  → `.active == 1` (mailcow returns INTEGER 1). DB kept (operator: no wipe).
- P-i: `modules/server/secret` deleted (operator rerolls cloudflare token anyway).
- P-j: `limit_req` zone `bnuy_public` + CF-IP map in
  `hosts/singularity/default.nix` (`services.nginx.commonHttpConfig`); applied
  on homepage, uptime-kuma, ntfy-sh, vaultwarden, mailcow vhosts.
- P-c: syncthing GUI auth wired (`guiPasswordFile` ← sops
  `syncthing/gui_password`, gui.user=bnuy, sops ordering on syncthing-init);
  folder passwords deliberately left out-of-band (nixpkgs module store-bakes
  plaintext, rule 7) — `# ponytail:` in syncthing.nix + secrets.yaml.example.
- FIREWALL CRASH FIX (2026-08-30): ALL `-m multiport` firewall rules replaced
  with one `--dport` rule per port. This kernel ships no `xt_multiport`
  (shrunk module set; nft_compat can't translate it), so `firewall.service`
  reload died with `RULE_APPEND failed` — pre-existing since Aug 23, and the
  reason every earlier `switch` aborted (leaving INPUT unfirewalled mid-flight).
  Rewrote: `syncthing.nix` (lanSubnets+tailscale0 rules), `pterodactyl.nix`
  (wings 8084/2022), mailcow `mailcow-docker-user-fence` DOCKER-USER rules
  (per-port loop RETURN+DROP). Also fixed the fence script's `IPT=@…` — with
  `writeShellScript` a literal `@/nix/store/…` is not substituted, so bash
  never executed iptables. VERIFIED: `nixos-rebuild switch` now exits 0,
  firewall.service active, `iptables -S DOCKER-USER` shows the 110/143 fence,
  nginx live config has the 444 default_server + `limit_req_zone bnuy_public`.

### NEXT (after this burst)

1. **Verify the whole tree**: `sudo nix flake check` (or at minimum
   `sudo nixos-rebuild build`). P-b is DONE and live-verified 2026-08-31
   (invited a missing active mailbox); see `vaultwarden/CHANGES.md`.
3. P-e DNS migration still pending (needs Cloudflare records + operator HTML).

### Verification commands (this shell was NOT root — sudo required)

```
sudo nix flake check            # or at minimum: sudo nixos-rebuild build
nix eval --raw .#nixosConfigurations.singularity.config.users.users.admin.initialPassword
```

Secrets follow `modules/server/.sops.yaml`; never commit plaintext.

## Open questions (operator decides)

1. **IdP (RESOLVED 2026-08-30):** Authentik CHOSEN (see decision log). Only
   remaining check: whether the pinned mailcow rev ships the OAuth2 Apps feature
   so authentik can use mailbox creds as the upstream identity source; if absent,
   provision authentik users from the mailcow mailbox list (passwords match only
   at creation time).
2. **`admin` account (RESOLVED 2026-08-30):** no SSH key, no Unix password —
   "no external access" per operator. Local console/out-of-band only.
4. **Does gating kuma/mail/password make sense?** No — answered: their own
   login pages are the gate (posture rule 2). Do not double-gate.

## Verification

- Every change: `nix flake check` (or at minimum `nixos-rebuild build`).
- Secrets: follow `modules/server/.sops.yaml` (edit via `sops secrets.yaml`,
  rotate via `sops updatekeys`); never commit plaintext.
- Per module touched, update its `CHANGES.md`; flag deliberate deviations from
  this file with `# ponytail:` comments.
- Public-exposure claims must be re-verified against
  `hosts/singularity/{default,variables}.nix` (tunnel hosts, records, split-DNS)
  after any vhost change.
