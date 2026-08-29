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
# VPN-only by design: the daemon binds loopback; nginx terminates TLS. No
# Cloudflare record, no port-forward - password.bnuy.dev resolves via
# Technitium split DNS (wire it in the host's services.technitium block:
# splitDns += domain), <lanDomain> via the local zone (localNames += its
# leftmost label). Tailnet clients reach it through the subnet router at the
# box's LAN IP.
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
# TLS: public vhost (domain) is LE via ACME DNS-01 (cloudflare) with a bnuy
# step-ca fallback; the LAN vhost (lanDomain) is bnuy step-ca only (no public
# DNS to validate against). Certificates synced to /var/lib/vaultwarden-ssl by
# vaultwarden-cert with a daily renewal timer, outside the daemon's
# StateDirectory because upstream pins that to 0700/UMask 0077, which the nginx
# user cannot traverse (same reason pterodactyl pins its LAN certs to group
# nginx).
# Coupling (accepted, see styleguide §2): the LE DNS-01 challenge reuses the
# vpn/cf_dns_token sops secret and the bnuy fallbacks reuse step-ca/password +
# step-ca/root_ca.crt - all present on singularity.

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

  # Public vhost (cfg.domain) uses LE via ACME DNS-01, synced with a bnuy
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
      virtualHosts = lib.listToAttrs (map (n: lib.nameValuePair n (mkVhost n)) vhosts);
    };

    # Standalone hosts need 443 opened; on singularity it already is.
    networking.firewall.allowedTCPPorts = [ 443 ];

    security.acme = lib.mkIf (cfg.domain != null) {
      acceptTerms = lib.mkDefault true;
      defaults.email = lib.mkDefault "enigma558@proton.me";
      certs.${cfg.domain} = {
        dnsProvider = "cloudflare";
        credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets."vpn/cf_dns_token".path;
        group = "nginx";
      };
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
            systemctl is-active --quiet nginx.service \
              && systemctl reload nginx.service || true
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
  };
}
