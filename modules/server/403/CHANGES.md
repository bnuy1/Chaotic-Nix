# 403 Landing Page Change Log

Server: Singularity. Operator-authored "access denied" page
(`services."403"`). Served by fence vhosts when a client that is NOT on the
LAN/tailnet trips a deny — never a real app (AGENTS posture rule 5).

## 2026-08-31 — 403 build fix (corrects the step-1 entry below)

The step-1 entry claimed the Nix `''` escape was fixed and `nix flake check`
passed, but a real **build** (`nixos-rebuild build`) failed on
`fence403-assets` with `403.css: Not a directory`. Two real bugs:

- `pkgs.symlinkJoin` is for merging DIRECTORIES via `lndir`; the module fed it
  three individual FILES, so `lndir` failed at build time. Switched to
  `pkgs.runCommand` that `ln -s` each leaf.
- The inline `''...''`-string CSS mangled `content: '';` (the `''` opens/breaks
  the Nix indented string — the `'''` "fix" produced `content: ';`). Moved the
  three compiled assets to tracked **plain files** (`403.css/html/js`) and
  reference them with `./403.css` etc, eliminating Nix string escaping entirely.

Verified: `nix build .#...services."403".assetsDir` succeeds and the produced
`403.css` contains the correct `content: '';`.

## 2026-08-31 — 403 module (plan step 1)

- **Module** (`403.nix`): `services."403"` exposes `assetsDir` = a
  `symlinkJoin` store dir holding `403.html`/`403.css`/`403.js`. Assets were
  hand-flattened from the operator's SCSS to plain CSS (no sass build dep);
  `darken(#F76B1C,20%) == #C65616` (rgb*0.8). Registered via `serverModuleMap`
  + `variables.nix serverModules."403" = true` → `services."403".enable`.
  - NAMING DEVIATION: plan.md named the service `services.fence403`, but the
    aggregator auto-generates `services.<mapKey>`; the key is the literal
    `"403"`, so the namespace is `services."403"`.
  - NIX ESCAPE FIX: CSS `content: '';` was a literal `''` inside a Nix `''`
    multiline string, breaking the parser — written as `content: ''';` (Nix
    escape) so the emitted CSS is `content: '';`. Verified via `nix eval`.
- **lib.nix helper** `tls.fence403` (`lib.nix:362`): returns nginx vhost bits
  for a pretty 403: `error_page 403 = /403.html;` (server `extraConfig`) + an
  exact-match location per asset (`root = assetsDir`, `allow all;` to override
  an inherited server-level `deny all`). Exported alongside the other TLS
  helpers. Callers merge it in (recursively, not `//`, so an existing
  `locations."/"` survives).
- **Attached** to the two fence vhosts that exist today:
  - `vpn.bnuy.dev-http` (headscale.nix): the fence leg denying the tunnel
    origin / non-LAN 403s are now served the landing page. Recursive merge
    keeps the existing `locations."/"` proxy + `vpnLanFence`.
  - `pterodactyl-403-default` (pterodactyl.nix): the 443 `default = true` stub
    changed from `return 444` → `deny all` + 403 landing (still not a real
    app; the LAN cert is never decrypted to content a browser can't reach).
- **Verification**: `sudo nix flake check` passes; `nix eval` confirms the
  default stub's `extraConfig` = `deny all;\nerror_page 403 = /403.html;`, the
  three asset locations resolve `root` to the store dedir, and the headscale
  `-http` vhost keeps both its `/` proxy AND the asset locations.

## Deferred (later plan steps)

- technitium `*.bnuy.dev` fenced panels (technitium split-DNS migration) —
  attach `fence403` there when those vhosts land.
- `*.network` split-DNS fence vhosts in technitium.nix are LAN-only today (no
  deny); the migration replaces them, so nothing to wrapp here yet.
