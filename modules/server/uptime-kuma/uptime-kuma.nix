# Uptime monitor (services.uptime-kuma) - kuma.bnuy.dev.
#
# Thin wrapper over the nixpkgs module (DynamicUser, sandbox, SQLite DB and
# in-app notification setup all live there). This module adds:
#   - a TLS vhost on kuma.bnuy.dev (mkTlsApp: LE via ACME http-01, bnuy fallback)
#   - a nightly restic backup of the SQLite state (/var/lib/uptime-kuma)
#
# Outage/info mail: uptime-kuma's SMTP channels submit through the host
# mailcow as uptime@bnuy.dev (mailbox provisioned there via mailbox_uptime,
# one minimal 25MB account). The password is set in the app's web UI and
# stored in its DB - no secret needed here.
#
# ntfy channel: registered + tested via uptime-kuma-ntfy-hook (register the
# "ntfy" notification in Kuma's DB through its own server code, then fire
# Kuma's ntfy provider at the shared sops ntfy/* credentials).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.uptime-kuma;
  tls = (import ../lib.nix) { inherit lib pkgs; };
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.uptime-kuma.settings.PORT = "3001"; # nixpkgs module default, pinned to match the vhost

      # Nightly restic of the SQLite state (monitor config, status history,
      # notification channels). Repo at /var/backups/uptime-kuma.
      # ponytail: stays root - SystemState dir is root:root 750 and the kuma
      # DynamicUser uid is not in a known group for restic to read it.
      systemd.tmpfiles.rules = [
        "d /var/backups/uptime-kuma/repo 0700 root root -"
        "d /var/cache/restic 0700 root root -"
      ];
      systemd.services.uptime-kuma-backup = {
        description = "Uptime Kuma: restic backup";
        after = [ "sops-nix.service" ];
        wants = [ "sops-nix.service" ];
        path = [ pkgs.restic ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 0;
          Nice = 10;
          Environment = "RESTIC_CACHE_DIR=/var/cache/restic";
        };
        script = ''
          set -eu
          export RESTIC_REPOSITORY=/var/backups/uptime-kuma/repo
          export RESTIC_PASSWORD=$(cat ${config.sops.secrets."uptime-kuma/backup_password".path})
          [ -d /var/lib/uptime-kuma ] || exit 0
          if ! restic snapshots >/dev/null 2>&1; then
            restic init
          fi
          restic backup /var/lib/uptime-kuma --tag uptime-kuma --exclude-caches
          restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 6 --prune
        '';
      };
      systemd.timers.uptime-kuma-backup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 06:30:00";
          Persistent = true;
        };
      };

      sops.secrets."uptime-kuma/backup_password" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };
      # Same host keyring as every other module (canonical keys live in the
      # vaultwarden/pterodactyl defaults).
      sops.age.sshKeyPaths = lib.mkDefault [ ];
      sops.age.keyFile = lib.mkDefault "/var/lib/sops-nix/keys.txt";

      # kuma -> ntfy hook. Registers an "ntfy" notification channel (user 1 =
      # bnuy) in Kuma's own DB - so future monitors can pick it - then fires a
      # test through Kuma's own ntfy provider. Uses the shared ntfy/* sops
      # secrets; skips cleanly until the operator fills real values. Manual:
      #   systemctl start uptime-kuma-ntfy-hook
      systemd.services.uptime-kuma-ntfy-hook = {
        description = "Uptime Kuma: register ntfy channel + send test";
        after = [ "sops-nix.service" "uptime-kuma.service" ];
        wants = [ "sops-nix.service" ];
        serviceConfig = {
          Type = "oneshot";
        };
        path = [ pkgs.nodejs ];
        script = ''
          set -eu
          NTFY_USER=$(cat ${config.sops.secrets."ntfy/user".path})
          NTFY_PASSWORD=$(cat ${config.sops.secrets."ntfy/password".path})
          NTFY_TOPIC=$(cat ${config.sops.secrets."ntfy/topic".path})
          for v in NTFY_USER NTFY_PASSWORD NTFY_TOPIC; do
            eval "val=\$$v"
            if [ -z "$val" ] || [ "$val" = "CHANGE_ME" ]; then
              echo "uptime-kuma-ntfy-hook: fill ntfy/* in modules/server/ntfy-sh/secrets.yaml first - skipped"
              exit 0
            fi
          done
          export NTFY_USER NTFY_PASSWORD NTFY_TOPIC
          cd ${cfg.package}/lib/node_modules/uptime-kuma
          node - <<'JS'
        const { Notification } = require("./server/notification");
        const sqlite3 = require("@louislam/sqlite3").verbose();
        const config = {
          name: "ntfy",
          type: "ntfy",
          ntfyserverurl: process.env.NTFY_SERVERURL || "https://ntfy.bnuy.dev",
          ntfytopic: process.env.NTFY_TOPIC,
          ntfyPriority: 3,
          ntfyPriorityDown: 5,
          ntfyAuthenticationMethod: "usernamePassword",
          ntfyusername: process.env.NTFY_USER,
          ntfypassword: process.env.NTFY_PASSWORD,
          ntfyCall: "",
          ntfyUseTemplate: false,
          isDefault: false,
        };
        const db = new sqlite3.Database(process.env.KUMA_DB || "/var/lib/uptime-kuma/kuma.db");
        db.serialize(() => {
          db.run("DELETE FROM notification WHERE name = ? AND user_id = ?", ["ntfy", 1]);
          db.run(
            "INSERT INTO notification(name, active, user_id, is_default, config) VALUES (?, 1, 1, 0, ?)",
            ["ntfy", JSON.stringify(config)]
          );
        });
        db.close();
        Notification.init();
        Notification.send(config, "hook test from uptime-kuma").then(
          (msg) => {
            console.log("ntfy:", msg);
          },
          (err) => {
            console.error("ntfy send failed:", err.message);
            process.exit(1);
          }
        );
        JS
        '';
      };
    }

    # Public TLS vhost: LE via http-01 (shared webroot), bnuy step-ca fallback.
    (tls.mkTlsApp {
      name = "uptime-kuma";
      domain = "kuma.bnuy.dev";
      port = 3001;
      passwordFile = config.sops.secrets."step-ca/password".path;
      acmeDns = true; # tunneled (Cloudflare edge fronts :80), so http-01 can't reach the origin
      cfTokenFile = config.sops.secrets."vpn/cf_dns_token".path;
      extraVhostConfig = "limit_req zone=bnuy_public burst=25 nodelay;";
    })
  ]);
}