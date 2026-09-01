# syncthing module — CHANGES

## 2026-08-30 (audit remediation — P-c)

- **P-c [~]** — GUI auth wired (posture rule 1 / AGENTS H3):
  - `guiPasswordFile = config.sops.secrets."syncthing/gui_password".path` —
    the nixpkgs module bcrypts it at runtime and PATCHes it via the REST API,
    so the plaintext never sits in the store.
  - `settings.gui.user = "bnuy"` (public username; the password is the secret).
  - `sops.secrets."syncthing/gui_password"` added (0400 syncthing) and
    `systemd.services.syncthing-init` now `wants`/`after` sops-nix.service so
    the config PATCH finds the file.
  - `secrets.yaml.example` created (redacted; includes the gui_password slot).
- **P-c — FOLDER-PASSWORD DEVIATION (`# ponytail:`)**: `settings.folders.<id>.password`
  is plaintext-baked into the nix store by the nixpkgs module (rule 7
  violation) with no file-backed alternative — left unset, to be set in the GUI
  out-of-band; they must match on every device of the folder anyway.
- **P-c [x]** — tailscale0 iptables rules: resolved MOOT (plan/AGENTS note,
  2026-08-31). The phone syncs over its own cleartext path, not the tailnet, so
  pinning these to a single tailnet IP adds nothing. Rules stay whole-tailscale0;
  syncthing.nix comment updated. Open item 3 (bnuy tailnet IP) closed.
