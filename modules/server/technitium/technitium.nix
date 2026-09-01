{ config, lib, pkgs, networkingHostname, ... }:

let
  cfg = config.services.technitium;
in
{
  options.services.technitium = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Technitium DNS Server for local DNS and ad-blocking";
    };

    localDomain = lib.mkOption {
      type = lib.types.str;
      default = "${networkingHostname}.local";
      description = "Local domain to resolve. Create a primary zone for this in the Technitium web UI";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address for Technitium to listen on. Set to LAN IP to serve other machines";
    };

    useLocally = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Configure this host to use Technitium as its DNS resolver";
    };

    localNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Hostnames to add as A records in the localDomain zone, pointing at listenAddress";
    };

    splitDns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public domains to answer authoritatively as Primary zones pointing at listenAddress. Split DNS: LAN clients get the LAN IP for services whose WAN path the router can't hairpin back (e.g. vpn.bnuy.dev:8443). External resolvers are unaffected.";
    };

    forwarders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://1.1.1.1/dns-query"
        "https://dns.google/dns-query"
        "https://dns.quad9.net/dns-query"
      ];
      description = "Upstream DNS forwarders. UDP/TCP 53 egress is blocked on this LAN, so the defaults are DNS-over-HTTPS endpoints";
    };
  };

  config = let
    networkVhosts = [
      { name = "technitium"; proxyPass = "http://127.0.0.1:5380"; }
      { name = "mailcow"; proxyPass = "https://127.0.0.1:8082"; } # mailserver httpsPort
      {
        # headscale has no web UI; serve the headscale-admin GUI (same routing
        # as the tailnet-only vhost in ../vpn/headscale.nix, minus the tailscale
        # bind). /api/ stays a same-origin proxy so the app's Bearer key works.
        name = "vpn";
        proxyPass = "http://127.0.0.1:${toString config.services.vpn-server.port}";
        locations = {
          "/" = { return = "302 /admin/"; };
          "/admin" = { return = "302 /admin/"; };
          "/admin/" = {
            proxyPass = "http://127.0.0.1:8083";
            basicAuthFile = config.sops.secrets."vpn/headscale_admin_htpasswd".path;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "/api/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.vpn-server.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            '';
          };
        };
      }
    ];
    networkSslDir = "/var/lib/technitium/ssl";
  in lib.mkIf cfg.enable {
    services.technitium-dns-server = {
      enable = true;
      openFirewall = true;
    };

    users.users.technitium = {
      isSystemUser = true;
      group = "technitium";
    };
    users.groups.technitium = { };

    systemd.services.technitium-dns-server.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "technitium";
      Group = lib.mkForce "technitium";
      StateDirectory = lib.mkForce "technitium-dns-server";
      ProtectSystem = lib.mkForce "strict";
      LogsDirectory = "technitium";
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
      # Restrict Technitium admin panel to localhost only
      extraCommands = ''
        iptables -A INPUT -p tcp --dport 5380 -s 127.0.0.0/8 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5380 -j DROP
      '';
    };

    networking.nameservers = lib.mkIf cfg.useLocally [ cfg.listenAddress ];

    # ponytail: AGENTS.md P-e asked to enable resolved DNSSEC validation locally,
# but this box resolves through Technitium which serves the unsigned local
# `network` zone + split-DNS primary zones authoritatively — resolved would
# fail those names (no RRSIG) and the box stops resolving its own services.
# Technitium already validates DNSSEC upstream; the LAN leg stays cleartext.
    services.resolved.settings.Resolve.DNSSEC = lib.mkIf cfg.useLocally false;

    systemd.tmpfiles.rules = [
      "d /var/lib/technitium-dns-server 0755 technitium technitium -"
      "d /var/log/technitium 0755 technitium technitium -"
      "d /var/backups/technitium 0755 root root -"
      "d /var/backups/technitium/repo 0755 root root -"
    ];

    sops.secrets."technitium/admin_password" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };
    sops.secrets."technitium/admin_username" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };
    sops.secrets."technitium/backup_password" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };

    # Declaratively create the localDomain zone + A records via the REST API
    # (same API the web console uses), so they survive a fresh data dir.
    # Admin password lives in SOPS; change it in the web UI and update the
    # secret to match.
    systemd.services.technitium-provision = {
      description = "Technitium: create local zone and records";
      after = [ "technitium-dns-server.service" "sops-nix.service" ];
      requires = [ "technitium-dns-server.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.curl pkgs.jq pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        API=http://127.0.0.1:5380
        USER=$(cat ${config.sops.secrets."technitium/admin_username".path})
        PASS=$(cat ${config.sops.secrets."technitium/admin_password".path})

        for i in $(seq 1 60); do
          curl -sf "$API/api/status" >/dev/null 2>&1 && break
          sleep 2
        done

        # Login can transiently fail right after the API answers /status
        # (observed 2026-08-23: ~90s of failures during a switch). Retry
        # here instead of relying on unit-restart roulette.
        TOKEN=
        for i in $(seq 1 30); do
          TOKEN=$(curl -sf "$API/api/user/login?user=$USER&pass=$PASS" | jq -r '.token // empty') || true
          [ -n "$TOKEN" ] && break
          sleep 2
        done
        test -n "$TOKEN"

        # Create the primary zone (fails quietly if it already exists).
        curl -s -X POST -H "Authorization: Bearer $TOKEN" \
          "$API/api/zones/create?zone=${cfg.localDomain}&type=Primary" || true

        # Add/overwrite one A record per name so runs are idempotent.
        for name in ${lib.concatStringsSep " " cfg.localNames}; do
          curl -s -X POST -H "Authorization: Bearer $TOKEN" \
            "$API/api/zones/records/add?zone=${cfg.localDomain}&domain=$name.${cfg.localDomain}&type=A&ipAddress=${cfg.listenAddress}&ttl=300&overwrite=true" \
            | jq -e '.status == "ok"' >/dev/null || echo "WARN: failed to provision $name.${cfg.localDomain}"
        done

        # Split DNS: a Primary zone per public domain, apex A record pointing at
        # this box (bypasses the router's no-hairpin NAT for LAN clients).
        for zone in ${lib.concatStringsSep " " cfg.splitDns}; do
          curl -s -X POST -H "Authorization: Bearer $TOKEN" \
            "$API/api/zones/create?zone=$zone&type=Primary" || true
          curl -s -X POST -H "Authorization: Bearer $TOKEN" \
            "$API/api/zones/records/add?zone=$zone&domain=$zone&type=A&ipAddress=${cfg.listenAddress}&ttl=300&overwrite=true" \
            | jq -e '.status == "ok"' >/dev/null || echo "WARN: failed to provision split-DNS $zone"
        done

        # Upstream forwarders (idempotent). UDP/TCP 53 egress is blocked on
        # this LAN, so the defaults are DNS-over-HTTPS endpoints.
        curl -s -G -X POST -H "Authorization: Bearer $TOKEN" \
          --data-urlencode "list=${lib.concatStringsSep "," cfg.forwarders}" \
          "$API/settings/forwarders/set" \
          | jq -e '.status == "ok"' >/dev/null \
          || echo "WARN: failed to set forwarders"
      '';
    };

    # HTTPS vhosts for the ${cfg.localDomain} zone names that proxy to services
    # (technitium/mailcow/vpn); the rest (pterodactyl/minecraft) land on the
    # pterodactyl panel default server. One step-ca cert covers all three, so
    # LAN clients get a verified cert once the step-ca root is installed.
    # singularity-local scheme: backends are this box's LAN services.
    systemd.services.technitium-network-cert = {
      description = "Technitium: issue ${cfg.localDomain} TLS cert from step-ca";
      wantedBy = [ "nginx.service" "multi-user.target" ];
      after = [ "step-ca.service" "sops-nix.service" ];
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
        mkdir -p ${networkSslDir}
        CERT_NAME=${(builtins.head networkVhosts).name}.${cfg.localDomain}
        ${pkgs.step-cli}/bin/step ca certificate \
          --ca-url https://127.0.0.1:9000 \
          --root ${../step-ca/root_ca.crt} \
          --provisioner admin \
          --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
          --force \
          ${lib.concatMapStringsSep " " (v: "--san ${v.name}.${cfg.localDomain}") networkVhosts} \
          "$CERT_NAME" /tmp/network-cert.pem /tmp/network-key.pem
        if ! cmp -s /tmp/network-cert.pem ${networkSslDir}/cert.pem \
           || ! cmp -s /tmp/network-key.pem ${networkSslDir}/key.pem; then
          install -m 0644 /tmp/network-cert.pem ${networkSslDir}/cert.pem
          install -m 0644 /tmp/network-key.pem ${networkSslDir}/key.pem
          # Reload only if nginx is already up (boot: nginx starts after us).
          systemctl is-active --quiet nginx.service \
            && systemctl reload nginx.service || true
        fi
      '';
    };

    systemd.timers.technitium-network-cert = {
      description = "Technitium: renew ${cfg.localDomain} TLS cert daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "technitium-network-cert.service";
      };
    };

    services.nginx.virtualHosts = lib.listToAttrs (map (v: {
      name = "${v.name}.${cfg.localDomain}";
      value = {
        addSSL = true;
        sslCertificate = "${networkSslDir}/cert.pem";
        sslCertificateKey = "${networkSslDir}/key.pem";
        locations = v.locations or {
          "/" = {
            proxyPass = v.proxyPass;
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Proto $scheme;
            '' + lib.optionalString (v.name == "mailcow") ''
              proxy_ssl_verify off;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header Authorization $http_authorization;
            '';
          };
        };
      };
    }) networkVhosts);

    systemd.services.technitium-backup = {
      description = "Technitium: restic backup (DNS config, zones, SSL certs)";
      after = [ "technitium-dns-server.service" "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      path = [ pkgs.restic pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ReadWritePaths = [ "/var/backups/technitium" ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        Nice = 10;
        Environment = "RESTIC_CACHE_DIR=/var/cache/restic";
      };
      script = ''
        set -eu
        export RESTIC_PASSWORD=$(cat ${config.sops.secrets."technitium/backup_password".path})
        export RESTIC_REPOSITORY=/var/backups/technitium/repo
        mkdir -p /var/backups/technitium/repo

        if ! restic snapshots >/dev/null 2>&1; then
          restic init
        fi
        restic backup /var/lib/technitium-dns-server ${networkSslDir} --tag technitium
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
      '';
    };

    systemd.timers.technitium-backup = {
      description = "Technitium: nightly backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 07:30:00";
        Persistent = true;
      };
    };
  };
}
