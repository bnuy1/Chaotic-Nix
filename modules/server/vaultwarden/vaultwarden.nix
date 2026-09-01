# Vaultwarden password manager (services.vaultwarden).
#
# Thin wrapper around nixpkgs' vaultwarden module, which already provides the
# daemon, static `vaultwarden` system user, 0700 StateDirectory and a full
# systemd sandbox (ProtectSystem=strict, CapabilityBoundingSet="",
# SystemCallFilter=@system-service ~@privileged, ...). This module adds only
# what nixpkgs does not do:
#   - TLS vhosts on shared 443 (step-ca leaf covering every name)
#   - sops secrets via a rendered EnvironmentFile
#   - restic backup into /var/backups/vaultwarden (per-module repo convention)
#
# By design: the daemon binds loopback; nginx terminates TLS. The public A
# record ships via the host's cloudflareDns block (grey-cloud, tracks the WAN
# IP) so remote clients + LE can reach the box; LAN clients resolve
# password.bnuy.dev via Technitium split DNS to the LAN IP (no hairpin),
# <lanDomain> via the local zone (localNames += its leftmost label). Tailnet
# clients reach it through the subnet router at the box's LAN IP.
#
# Threat model = mailcow webmail: the app's own auth gates everything.
# Headscale policy is accept-only (no deny action) and nginx cannot see
# tailnet identity, so guest tier (whose ACL allows 443 on the service host)
# can reach the login page but nothing else. Fully guest-dark would need a
# dedicated port in services.vpn-server.acl.staffPorts instead.
#
# First-user bootstrap (signups are off by default):
#   1. set serverModules.vaultwarden.signupsAllowed = true, rebuild
#   2. create your account at https://password.bnuy.dev
#   3. flip it back to false, rebuild
#
# Secrets: ./secrets.yaml (see secrets.yaml.example). ADMIN_TOKEN reaches the
# daemon through a sops-rendered EnvironmentFile (0600, owner vaultwarden) -
# never through services.vaultwarden.config, which lands in a world-readable
# nix store path.
#
# TLS: public vhost (domain) is LE via ACME http-01 (shared webroot, same as
# mail) with a bnuy step-ca fallback; the LAN vhost (lanDomain) is bnuy
# step-ca only (no public DNS to validate against). Certificates synced to
# /var/lib/vaultwarden-ssl by vaultwarden-cert with a daily renewal timer,
# outside the daemon's StateDirectory because upstream pins that to
# 0700/UMask 0077, which the nginx user cannot traverse (same reason
# pterodactyl pins its LAN certs to group nginx).
# Coupling (accepted, see styleguide §2): the bnuy fallbacks reuse
# step-ca/password + step-ca/root_ca.crt - all present on singularity.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.vaultwarden;

  # Mirror nixpkgs' StateDirectory choice so backup paths always match where
  # the daemon actually lives (pre-24.11 stateVersion hosts used bitwarden_rs).
  dataDir =
    if lib.versionOlder config.system.stateVersion "24.11" then "/var/lib/bitwarden_rs" else "/var/lib/vaultwarden";

  sslDir = "/var/lib/vaultwarden-ssl";
  backupDir = "/var/backups/vaultwarden";

  # Public vhost (cfg.domain) uses LE via ACME http-01, synced with a bnuy
  # step-ca fallback into le-cert.pem/le-key.pem. The LAN vhost (cfg.lanDomain)
  # uses a bnuy-only leaf in cert.pem/key.pem (no public DNS to LE-validate).
  acmeDir = lib.optionalString (cfg.domain != null) "/var/lib/acme/${cfg.domain}";
  leCert = "${acmeDir}/fullchain.pem";
  leKey = "${acmeDir}/key.pem";

  # Fixed loopback port (nginx proxies it); don't read cfg.config here -
  # that would recurse once we pin ROCKET_PORT below.
  port = 8222;
  vhosts = lib.optional (cfg.domain != null) cfg.domain ++ lib.optional (cfg.lanDomain != null) cfg.lanDomain;

  # The public domain vhost serves the LE-primary/bnuy-fallback bundle; the LAN
  # vhost serves the bnuy-only leaf.
  mkVhost = serverName:
    let
      isPublic = serverName == cfg.domain;
      certFile = if isPublic then "le-cert.pem" else "cert.pem";
      keyFile = if isPublic then "le-key.pem" else "key.pem";
    in
    {
      inherit serverName;
      addSSL = true;
      http2 = true;
      # Pin 443 only (same as mail's vhost): the addSSL default also listens on
      # 80 and would shadow the -http challenge vhost.
      listen = [
        {
          addr = "0.0.0.0";
          port = 443;
          ssl = true;
        }
      ];
      sslCertificate = "${sslDir}/${certFile}";
      sslCertificateKey = "${sslDir}/${keyFile}";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          # IP_HEADER=X-Real-IP so vaultwarden rate-limits real clients.
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          limit_req zone=bnuy_public burst=25 nodelay;
        '';
      };
    };
in
{
  options.services.vaultwarden = {
    # Second vhost on the Technitium local zone. null = single-vhost setups.
    lanDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "password.network";
      description = "Optional second vhost name (Technitium local zone A record)";
    };
    signupsAllowed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open signups. Only flip on to bootstrap the first user account,
        then back off.
      '';
    };
    mailcowSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Reconcile vaultwarden accounts against the mailcow mailbox list
        (mailcow = source of truth for identities, AGENTS.md). Invites missing
        accounts, disables ones whose mailbox is gone; never touches existing
        active accounts. Authenticates to the /admin API with the
        vaultwarden/admin_raw_token secret (POST /admin cookie flow).
      '';
    };
    syncExcludedAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "vaultwarden@bnuy.dev"
        "pterodactyl@bnuy.dev"
        "immich@bnuy.dev"
        "singularity@bnuy.dev"
        "uptime@bnuy.dev"
      ];
      description = "Mailbox addresses to never create vaultwarden accounts for (service mailboxes)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.vaultwarden = {
      dbBackend = "sqlite";
      # Sane default for standalone use; hosts set the real name via
      # serverModules.vaultwarden.domain.
      domain = lib.mkDefault "password.bnuy.dev";
      environmentFile = config.sops.templates."vaultwarden/env".path;
      # Upstream defaults ROCKET_ADDRESS to ::1 and ROCKET_PORT to 8000; pin
      # both so the nginx proxyPass above (8222) dials the right socket.
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = port;
        SIGNUPS_ALLOWED = cfg.signupsAllowed;
        INVITATIONS_ALLOWED = false;
        SHOW_PASSWORD_HINT = false;
        IP_HEADER = "X-Real-IP";
      };
    };

    # ---------------------------------------------------------------------
    # sops secrets (sopsFile set explicitly: pterodactyl module owns
    # sops.defaultSopsFile for this host).
    # ---------------------------------------------------------------------
    sops.secrets."vaultwarden/admin_token" = {
      sopsFile = ./secrets.yaml;
      owner = "vaultwarden";
      mode = "0400";
    };
    # RAW admin-panel login secret (the plaintext partner that argon2-verifies
    # against the admin_token hash). The /admin API no longer accepts a Bearer
    # header - it only issues a VW_ADMIN session cookie from POST /admin
    # (token=<raw>). The daemon env keeps only the hash (admin_token); this raw
    # value is read by the root-run mailcow-sync timer to obtain that cookie.
    sops.secrets."vaultwarden/admin_raw_token" = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };
    sops.secrets."vaultwarden/smtp_username" = {
      sopsFile = ./secrets.yaml;
      owner = "vaultwarden";
      mode = "0400";
    };
    sops.secrets."vaultwarden/smtp_password" = {
      sopsFile = ./secrets.yaml;
      owner = "vaultwarden";
      mode = "0400";
    };
    # Read by the root-run backup unit only.
    sops.secrets."vaultwarden/backup_password" = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    # Rendered env file for secrets that must arrive as environment variables
    # (systemd EnvironmentFile). Empty SMTP values leave mail disabled.
    sops.templates."vaultwarden/env" = {
      content = ''
        ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin_token"}
        SMTP_USERNAME=${config.sops.placeholder."vaultwarden/smtp_username"}
        SMTP_PASSWORD=${config.sops.placeholder."vaultwarden/smtp_password"}
        # Mailcow postfix submission on the local server (STARTTLS). The FROM
        # is the dedicated vaultwarden@ mailbox; SMTP_USERNAME/PASSWORD must be
        # that mailbox's creds (== mailcow/mailbox_vaultwarden).
        DOMAIN=https://${cfg.domain}
        SMTP_HOST=mail.bnuy.dev
        SMTP_PORT=587
        SMTP_SECURITY=starttls
        SMTP_FROM=vaultwarden@bnuy.dev
        SMTP_FROM_NAME=Bnuy Vaultwarden
      '';
      owner = "vaultwarden";
      mode = "0600";
    };

    # Same keyring the other server modules use; keep defaults overridable so
    # the module stays usable outside this repo.
    sops.age.sshKeyPaths = lib.mkDefault [ ];
    sops.age.keyFile = lib.mkDefault "/var/lib/sops-nix/keys.txt";

    # ---------------------------------------------------------------------
    # Web vault vhosts. Shared 443 (SNI-routed alongside mailcow/headscale).
    # Public vhost serves the LE-primary/bnuy-fallback bundle (browser-facing);
    # the LAN vhost serves the bnuy-only leaf (sync in vaultwarden-cert).
    # ---------------------------------------------------------------------
    services.nginx = {
      enable = lib.mkDefault true;
      virtualHosts =
        lib.listToAttrs (map (n: lib.nameValuePair n (mkVhost n)) vhosts)
        // lib.optionalAttrs (cfg.domain != null) {
          # Port 80: serve the http-01 challenge (useACMEHost) + redirect the
          # rest. Same shape as mail's -http vhost.
          "${cfg.domain}-http" = {
            serverName = cfg.domain;
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            useACMEHost = cfg.domain;
            locations."/" = {
              extraConfig = "return 301 https://$host$request_uri;";
            };
          };
        };
    };

    # Standalone hosts need 443+80 opened; on singularity they already are.
    networking.firewall.allowedTCPPorts = [ 443 80 ];

    security.acme = lib.mkIf (cfg.domain != null) {
      acceptTerms = lib.mkDefault true;
      defaults.email = lib.mkDefault "enigma558@proton.me";
      certs.${cfg.domain} = {
        # DNS-01: password.bnuy.dev is tunneled (Cloudflare edge fronts :80),
        # so http-01 can't reach the origin; prove the zone via the CF API
        # (same token + precedent as vpn.bnuy.dev). The -http vhost above
        # stays as a plain 301 redirect.
        dnsProvider = "cloudflare";
        credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets."vpn/cf_dns_token".path;
        group = "nginx";
      };
    };

    # DNS-01 zone-walk guard (same as lib.nix mkAcme): local Technitium serves
    # authoritative SOA for this splitDns FQDN, which would trap lego's SOA
    # walk at the local zone forever. Overlay public resolvers onto the acme
    # unit so the walk reaches the real bnuy.dev zone.
    systemd.services.acme-dns-public = lib.mkIf (cfg.domain != null) {
      description = "Write public-resolver resolv.conf for DNS-01 acme units";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /run/acme-dns-public
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /run/acme-dns-public/resolv.conf
        chmod 0644 /run/acme-dns-public/resolv.conf
      '';
    };
    systemd.services."acme-${cfg.domain}" = lib.mkIf (cfg.domain != null) {
      after = [ "acme-dns-public.service" ];
      requires = [ "acme-dns-public.service" ];
      serviceConfig.BindReadOnlyPaths = [ "/run/acme-dns-public/resolv.conf:/etc/resolv.conf" ];
    };
    # The lego SOA walk itself runs in the order-renew unit on renewals and at
    # the end of the initial issue - it needs the same overlay.
    systemd.services."acme-order-renew-${cfg.domain}" = lib.mkIf (cfg.domain != null) {
      after = [ "acme-dns-public.service" ];
      requires = [ "acme-dns-public.service" ];
      serviceConfig.BindReadOnlyPaths = [ "/run/acme-dns-public/resolv.conf:/etc/resolv.conf" ];
    };

    systemd.services.vaultwarden-cert = {
      description = "Vaultwarden: sync TLS certs (LE primary, bnuy fallback)";
      wantedBy = [ "nginx.service" "multi-user.target" ];
      after = [
        "step-ca.service"
        "sops-nix.service"
      ] ++ lib.optional (cfg.domain != null) "acme-${cfg.domain}.service";
      # nginx's config references the cert files; never let it start (or get
      # reloaded by a switch) before they exist.
      before = [ "nginx.service" ];
      path = [ pkgs.openssl pkgs.coreutils pkgs.diffutils pkgs.step-cli pkgs.systemd ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        TimeoutStartSec = 0;
      };
      script = ''
        set -eu
        mkdir -p ${sslDir}
        chown vaultwarden:nginx ${sslDir}
        chmod 0750 ${sslDir}

        # LAN vhost: bnuy-only leaf covering cfg.lanDomain.
        ${lib.optionalString (cfg.lanDomain != null) ''
          ${pkgs.step-cli}/bin/step ca certificate \
            --ca-url https://127.0.0.1:9000 \
            --root ${../step-ca/root_ca.crt} \
            --provisioner admin \
            --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
            --force --san ${cfg.lanDomain} \
            ${cfg.lanDomain} /tmp/vw-lan-cert.pem /tmp/vw-lan-key.pem
          if ! cmp -s /tmp/vw-lan-cert.pem ${sslDir}/cert.pem \
             || ! cmp -s /tmp/vw-lan-key.pem ${sslDir}/key.pem; then
            install -o root -g nginx -m 0640 /tmp/vw-lan-cert.pem ${sslDir}/cert.pem
            install -o root -g nginx -m 0640 /tmp/vw-lan-key.pem ${sslDir}/key.pem
          fi
        ''}

        # Public vhost: the real LE cert when valid (acme-success + 21 days),
        # else a bnuy step-ca fallback covering cfg.domain.
        ${lib.optionalString (cfg.domain != null) ''
          SRC_CERT=/dev/null
          SRC_KEY=/dev/null
          if [ -f ${acmeDir}/acme-success ] \
             && [ -f ${leCert} ] && [ -f ${leKey} ] \
             && openssl x509 -checkend $((21 * 86400)) -noout -in ${leCert} 2>/dev/null; then
            SRC_CERT=${leCert}
            SRC_KEY=${leKey}
          else
            ${pkgs.step-cli}/bin/step ca certificate \
              --ca-url https://127.0.0.1:9000 \
              --root ${../step-ca/root_ca.crt} \
              --provisioner admin \
              --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
              --force --san ${cfg.domain} \
              ${cfg.domain} /tmp/vw-pub-cert.pem /tmp/vw-pub-key.pem
            SRC_CERT=/tmp/vw-pub-cert.pem
            SRC_KEY=/tmp/vw-pub-key.pem
          fi
          if ! cmp -s "$SRC_CERT" ${sslDir}/le-cert.pem \
             || ! cmp -s "$SRC_KEY" ${sslDir}/le-key.pem; then
            install -o root -g nginx -m 0640 "$SRC_CERT" ${sslDir}/le-cert.pem
            install -o root -g nginx -m 0640 "$SRC_KEY" ${sslDir}/le-key.pem
            # Reload only when nginx is already up: on boot nginx starts after
            # us (before=nginx.service), and try-reload-or-restart would queue
            # a restart that deadlocks on the pending nginx start job.
            # --no-block prevents the reload job from deadlocking a concurrent
            # cert-sync (reload waits on the running sync whose script is
            # waiting on that same reload).
            systemctl is-active --quiet nginx.service \
              && systemctl reload nginx.service --no-block || true
          fi
        ''}
      '';
    };

    systemd.timers.vaultwarden-cert = {
      description = "Vaultwarden: renew vhost TLS cert daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # ---------------------------------------------------------------------
    # Backup: nightly restic into this module's own repo under /var/backups
    # (per-module repo convention). A consistent staging copy first: restic
    # reading the live sqlite file risks a corrupt snapshot.
    # ponytail: runs as root - the state dir is 0700 vaultwarden, which no
    # group membership grants; non-root would need ACLED dirs for no gain.
    # ---------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d /var/backups 0755 root root -"
      "d ${backupDir} 0700 root root -"
      "d /var/cache/restic 0700 root root -"
    ];

    systemd.services.vaultwarden-backup = {
      description = "Vaultwarden: restic backup";
      after = [ "vaultwarden.service" "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      path = [
        pkgs.restic
        pkgs.sqlite
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = backupDir;
        ReadWritePaths = [ backupDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        Nice = 10;
        # systemd gives oneshot units no $HOME/$XDG_CACHE_HOME; restic refuses
        # to run without a cache dir, so pin one.
        Environment = "RESTIC_CACHE_DIR=/var/cache/restic";
      };
      script = ''
        set -eu
        export RESTIC_PASSWORD=$(cat ${config.sops.secrets."vaultwarden/backup_password".path})
        # Bare `restic` has no default repo; point it at this module's repo.
        export RESTIC_REPOSITORY=${backupDir}/repo
        mkdir -p ${backupDir}/repo ${backupDir}/staging

        rm -rf ${backupDir}/staging/*
        sqlite3 ${dataDir}/db.sqlite3 ".backup '${backupDir}/staging/db.sqlite3'"
        for d in attachments sends; do
          [ -d ${dataDir}/$d ] && cp -r ${dataDir}/$d ${backupDir}/staging/
        done

        if ! restic snapshots >/dev/null 2>&1; then
          restic init
        fi
        restic backup ${backupDir}/staging --tag vaultwarden
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
      '';
    };

    # Nightly, inside the 05:00-08:00 backup window (§6), 30 min after
    # pterodactyl and before mailcow.
    systemd.timers.vaultwarden-backup = {
      description = "Vaultwarden: nightly backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:30:00";
        Persistent = true;
      };
    };

    # ---------------------------------------------------------------------
    # vaultwarden-mailcow-sync: mailcow mailbox list -> vaultwarden accounts.
    # The mailcow GAL is the identity source (AGENTS.md "Identity"); this keeps
    # the vaultwarden user list in step. Dials the mailcow container's
    # httpsPort (8082) directly - the same loopback path as mailcow-provision,
    # so the host-nginx /api/v1 fence never applies. Runs as root: it has to
    # read both secrets (`mailcow/api_key` is 0400 mailcow, `admin_raw_token`
    # is 0400 root) - no single non-root identity holds both.
    #
    # AUTH (verified vs vaultwarden 1.37.1 admin.rs): the admin API is
    # cookie-session only. There is no `Authorization: Bearer` path for admin.
    # Login is `POST /admin` (x-www-form-urlencoded `token=<raw>`) which
    # argon2-verifies the RAW secret against the configured ADMIN_TOKEN hash
    # and sets a `VW_ADMIN` JWT cookie (path=/admin). Every wildcard admin
    # route below carries that cookie. The timer logs in fresh on every run so
    # the short-lived session cookie can never go stale.
    #   - list    GET  /admin/users                                -> JSON array
    #   - invite  POST /admin/invite      {"email": "..."}         -> 409 if exists
    #   - disable POST /admin/users/<id>/disable  (JSON format)
    #   - enable  POST /admin/users/<id>/enable   (JSON format)
    # ponytail: compares by email string only; a mailbox rename shows up as
    # invite+disable (a fresh invite for the new address, the old left
    # disabled). API shapes were verified against the pinned 1.37.1 source.
    # ---------------------------------------------------------------------
    systemd.services.vaultwarden-mailcow-sync = lib.mkIf cfg.mailcowSync {
      description = "Vaultwarden: reconcile accounts against the mailcow mailbox list";
      after = [
        "vaultwarden.service"
        "mailcow-setup.service"
        "sops-nix.service"
      ];
      wants = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.curl
        pkgs.jq
        pkgs.gnugrep
        pkgs.gawk
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 60;
      };
      script = ''
        set -eu
        MAILCOW_API=https://127.0.0.1:8082/api/v1   # mailserver httpsPort default
        VW_ADMIN=http://127.0.0.1:${toString port}/admin
        API_KEY=$(cat ${config.sops.secrets."mailcow/api_key".path})
        ADMIN_RAW=$(cat ${config.sops.secrets."vaultwarden/admin_raw_token".path})
        JAR=/run/vw-sync-cookies
        EXCLUDED='${lib.concatStringsSep "|" cfg.syncExcludedAddresses}'

        # Obtain a VW_ADMIN session cookie (argon2-verified against the raw).
        curl -sf -c "$JAR" -o /dev/null -X POST \
          -H "Content-Type: application/x-www-form-urlencoded" \
          --data-urlencode "token=$ADMIN_RAW" \
          "$VW_ADMIN"

        # Active mailcow mailboxes, minus the excluded service addresses.
        # mailcow returns `active` as an INTEGER 1 (not the string "1").
        curl -sfk -H "X-API-Key: $API_KEY" "$MAILCOW_API/get/mailbox/all" \
          | jq -r '.[] | select(.active == 1) | .username' \
          | grep -Ev "^($EXCLUDED)$" | sort -u > /run/vw-sync-mailboxes

        # Existing vaultwarden users as "id<TAB>email" (admin session cookie).
        curl -sf -b "$JAR" "$VW_ADMIN/users" \
          | jq -r '.[]? | select(.email != "") | [.id, .email] | @tsv' \
          | sort -k2 > /run/vw-sync-users

        # Invite missing (mailcow has, vaultwarden has not). invite_user 409s
        # if the account already exists, so skip only what we already have.
        cut -f2 /run/vw-sync-users | sort -u \
          | comm -23 /run/vw-sync-mailboxes - | while read -r email; do
            curl -sf -b "$JAR" -X POST -H "Content-Type: application/json" \
              -d "{\"email\":\"$email\"}" "$VW_ADMIN/invite" >/dev/null \
              || echo "WARN: invite failed for $email"
          done

        # Disable removed (vaultwarden has, mailbox gone).
        cut -f2 /run/vw-sync-users | sort -u \
          | comm -13 /run/vw-sync-mailboxes - | while read -r email; do
            id=$(awk -F'\t' -v e="$email" '$2==e{print $1; exit}' /run/vw-sync-users)
            if [ -n "$id" ]; then
              curl -sf -b "$JAR" -X POST -H "Content-Type: application/json" \
                "$VW_ADMIN/users/$id/disable" >/dev/null \
                || echo "WARN: disable failed for $email"
            fi
          done
      '';
    };

    systemd.timers.vaultwarden-mailcow-sync = lib.mkIf cfg.mailcowSync {
      description = "Vaultwarden: hourly mailcow account reconcile";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
