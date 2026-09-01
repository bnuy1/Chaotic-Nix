# Push notifications (services.ntfy-sh) - ntfy.bnuy.dev.
#
# Thin wrapper over the nixpkgs module (DynamicUser, SQLite cache, sandbox and
# StateDirectory all live there). This module adds just:
#   - a TLS vhost on ntfy.bnuy.dev (mkTlsApp: LE via ACME http-01, bnuy fallback)
#   - base-url so push delivery / attachments / iOS work against the public name
#   - auth gating: deny-all by default. No anonymous access to any topic, full
#     stop. The only principals with grants are the two bootstrapped users:
#       - `bnuy`: read-write, WILDCARD across ALL topics (*) - devices use a
#         random secret topic name, so bnuy must match every topic
#       - `user`: read-only, WILDCARD grant across ALL topics (*)
#     Everything else - anyone without credentials, any topic without a
#     specific grant - is 403. Kept public-facing on purpose - the caller's
#     phone connects on cellular - so protection is auth + TLS, not network
#     hiding. Prevents third parties pulling the feed or injecting spam.
#
# Threat model note: ntfy has NO end-to-end encryption (upstream #69 open since
# 2021; no --encrypt flag in any shipped client). Messages are readable in
# cleartext by the server itself and are protected in transit by TLS only.
# deny-all + the two users close the "anyone can subscribe" hole; trusting LE
# TLS is the accepted stance for the phone path.
#
# Both accounts are created idempotently at boot with throwaway bcrypt
# passwords; SET THE REAL ONES yourself (run as root - the DynamicUser
# auth-file is not writable by the `ntfy-sh` user; prompts twice, survives
# rebuilds - the bootstrap skip-if-exists on every start):
#
#     sudo ntfy user change-pass bnuy      # rw across all topics (wildcard)
#     sudo ntfy user change-pass user      # read-only across all topics
#
# Cache + attachments live in /var/lib/ntfy-sh (ephemeral by nature - no
# restic: the cache re-reads from the relay and attachments are disposable).
# No email: ntfy's outbound email needs a subscription service and is
# configured elsewhere if ever wanted.
#
# Sender hooks: the box can publish into this ntfy from any shell via the
# `ntfy-send` helper (installed on PATH) and from Uptime-Kuma via its
# uptime-kuma-ntfy-hook unit. All of them read the shared sops secrets in
# secrets.yaml here (ntfy/user, ntfy/password, ntfy/topic) - fill the real
# values in the example file and `sops --encrypt --in-place` it; every hook
# skips cleanly on the CHANGE_ME placeholder until then.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ntfy-sh;
  tls = (import ../lib.nix) { inherit lib pkgs; };
  # Generic host-side sender: `ntfy-send [title] message` bridges any shell
  # hook (backup units, cron, operators) into this ntfy. Reads the shared
  # sops secrets below (ntfy/user, ntfy/password, ntfy/topic).
  ntfy-send = pkgs.writeShellScriptBin "ntfy-send" ''
    set -eu
    NTFY_USER=$(cat ${config.sops.secrets."ntfy/user".path})
    NTFY_PASSWORD=$(cat ${config.sops.secrets."ntfy/password".path})
    NTFY_TOPIC=$(cat ${config.sops.secrets."ntfy/topic".path})
    for v in NTFY_USER NTFY_PASSWORD NTFY_TOPIC; do
      eval "val=\$$v"
      if [ -z "$val" ] || [ "$val" = "CHANGE_ME" ]; then
        echo "ntfy-send: fill ntfy/* in modules/server/ntfy-sh/secrets.yaml first" >&2
        exit 1
      fi
    done
    exec ${cfg.package}/bin/ntfy send -u "$NTFY_USER:$NTFY_PASSWORD" "https://ntfy.bnuy.dev/$NTFY_TOPIC" "$@"
  '';
  bootstrap = pkgs.writeShellScript "ntfy-sh-bootstrap" ''
    set -euo pipefail
    NTFY_PASSWORD="$(openssl rand -base64 48)" ntfy user add --ignore-exists bnuy
    ntfy access bnuy "*" rw
    NTFY_PASSWORD="$(openssl rand -base64 48)" ntfy user add --ignore-exists user
    ntfy access user "*" ro
  '';
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.ntfy-sh.settings = {
        "base-url" = "https://ntfy.bnuy.dev";
        # nixpkgs module default, pinned so the vhost matches.
        "listen-http" = "127.0.0.1:2586";
        # Everything is 403 unless granted - no anonymous perms on any topic.
        "auth-default-access" = "deny-all";
      };

      # Create users `bnuy` (rw on `bnuy`) + `user` (ro wildcard `*`).
      # Runs after the server has created the auth DB (the CLI refuses to create
      # user.db itself). Runs every boot but skip-if-exists / setting the same
      # grant are idempotent. Runs as root: the auth-file is created by the
      # DynamicUser service and systemd may not chown it to the unit's UID -
      # root writes it, the server only ever needs read access for auth checks.
      systemd.services.ntfy-sh-bootstrap = {
        description = "ntfy auth bootstrap (bnuy rw / user ro-all)";
        after = [ "ntfy-sh.service" ];
        wantedBy = [ "ntfy-sh.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = bootstrap;
        };
        path = [ cfg.package pkgs.openssl ];
      };

      # Shared sender credentials for the hook machine (ntfy-send, kuma hook).
      # Operator fills the example in secrets.yaml, encrypts, and the values
      # land here under /run/secrets/ntfy/* (placeholders keep every hook
      # skipping cleanly until then). ntfy creds never live in nix - only in
      # this age-encrypted file.
      sops.secrets."ntfy/user" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };
      sops.secrets."ntfy/password" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };
      sops.secrets."ntfy/topic" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };

      environment.systemPackages = [ ntfy-send ];
    }
    (tls.mkTlsApp {
      name = "ntfy-sh";
      domain = "ntfy.bnuy.dev";
      port = 2586;
      websockets = true;
      extraVhostConfig = ''
        # ntfy's SSE push keeps the connection open for 45s+; matches the
        # app's own recommended proxy config.
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        limit_req zone=bnuy_public burst=25 nodelay;
      '';
      passwordFile = config.sops.secrets."step-ca/password".path;
      acmeDns = true; # tunneled (Cloudflare edge fronts :80), so http-01 can't reach the origin
      cfTokenFile = config.sops.secrets."vpn/cf_dns_token".path;
    })
  ]);
}