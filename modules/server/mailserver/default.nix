# mailcow docker mailserver.
#
# Runs the mailcow-dockerized stack (pinned via the `mailcow` flake input) with
# Docker rootful, HTTPS terminated by the host nginx on 443 (Let's Encrypt via
# webroot, step-ca as offline fallback), and everything else proxied on
# 127.0.0.1. Mail ports (25/465/587/110/143/993/995/4190) are published by
# Docker directly.
#
# Deploy order at boot:
#   mailcow-seed      write a bootstrap TLS cert (data/assets/ssl)
#   mailcow-setup     rsync pinned repo -> /var/lib/mailcow, write mailcow.conf
#                     (WRITE-ONCE) + .env symlink, `docker compose up -d`
#   mailcow-certs     copy host LE cert into mailcow (step-ca fallback), reload
#   mailcow-provision first-boot: admin password, domain, mailboxes, DKIM hint
#   mailcow-backup    daily restic (config + named volumes + mysql dump)
#
# DNS to create (external, done by hand): A mail/autodiscover/autoconfig,
# MX, SPF, DKIM (printed by mailcow-provision), DMARC, PTR. See the module
# README notes in mailcow.conf below.
{
  config,
  lib,
  pkgs,
  mailcowSrc,
  ...
}:

let
  cfg = config.services.mailcow;

  # sops-nix resolves each secret to /run/secrets/... at boot. Namespaces match
  # the mailcow: keys present in ./secrets.yaml.
  secret = key: config.sops.secrets."mailcow/${key}".path;

  sslDir = "${cfg.dataDir}/data/assets/ssl";
  acmeDir = "/var/lib/acme/${cfg.domain}";
  leCert = "${acmeDir}/fullchain.pem";
  leKey = "${acmeDir}/key.pem";

  # autodiscover/autoconfig/mta-sts for every mail domain.
  sanNames = lib.concatLists (
    map (d: [
      "autodiscover.${d}"
      "autoconfig.${d}"
      "mta-sts.${d}"
    ]) cfg.mailDomains
  );
  aliases = lib.remove null (lib.unique (sanNames ++ cfg.mailDomains));

  project = cfg.project;
in
{
  options.services.mailcow = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the mailcow docker mailserver";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "mail.bnuy.dev";
      description = "MAILCOW_HOSTNAME (the mail server FQDN)";
    };
    mailDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "bnuy.dev" ];
      description = "Mail domains hosted on this server";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "bnuy@bnuy.dev";
      description = "Let's Encrypt notification address";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mailcow";
      description = "mailcow install + data directory";
    };
    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8085;
      description = "Loopback HTTP port (mailcow http->https redirect listener)";
    };
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Loopback HTTPS port the host nginx proxies to";
    };
    project = lib.mkOption {
      type = lib.types.str;
      default = "mailcowdockerized";
      description = "Docker compose project name (volume/container prefix)";
    };
    mailboxes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            address = lib.mkOption { type = lib.types.str; };
            name = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            passwordSopsKey = lib.mkOption { type = lib.types.str; };
            quota = lib.mkOption {
              type = lib.types.int;
              default = 10240;
              description = "Quota in MB";
            };
          };
        }
      );
      default = [
        {
          address = "bnuy@bnuy.dev";
          name = "Mal";
          passwordSopsKey = "mailbox_bnuy";
        }
        {
          address = "raina@bnuy.dev";
          name = "Raina";
          passwordSopsKey = "mailbox_raina";
        }
      ];
      description = "Mailboxes created by mailcow-provision on first boot";
    };
  };

  config = lib.mkIf cfg.enable {
    # mailcow requires a rootful Docker daemon (dockerapi/netfilter containers).
    virtualisation.docker = {
      enable = lib.mkDefault true;
      # mkForce: modules/core/virtualisation.nix enables rootless when
      # vars.dockerEnable, which breaks mailcow (mounts /var/run/docker.sock,
      # host-network privileged netfilter container).
      rootless.enable = lib.mkForce false;
    };

    # Dedicated user for the mailcow units (hygiene only: the docker group is
    # root-equivalent, so this is not a real security boundary). docker group
    # for the socket, nginx group to read the host LE certs (0640 acme:nginx).
    users.groups.mailcow = { };
    users.users.mailcow = {
      isSystemUser = true;
      group = "mailcow";
      home = cfg.dataDir;
      createHome = true;
      # 0750 + nginx in the mailcow group: host nginx reads the TLS certs from
      # data/assets/ssl (default system-user home is 0700, untraversable).
      homeMode = "0750";
      extraGroups = [
        "docker"
        "nginx"
      ];
    };

    # Host nginx needs to traverse the mailcow home to read data/assets/ssl.
    users.users.nginx.extraGroups = [ "mailcow" ];

    # The mail vhost reads its cert from data/assets/ssl (written by
    # mailcow-seed/mailcow-certs); make sure nginx starts after the bootstrap
    # cert exists so it never fails on a missing file.
    systemd.services.nginx.after = [ "mailcow-seed.service" ];

    # Webmail/admin UI behind the host nginx. One LE cert (SANs for the
    # autodiscover/autoconfig/mta-sts aliases) served on 443; proxy to mailcow's
    # internal HTTPS listener.
    #
    # Cert comes from mailcow-certs' sync dir, NOT the acme dir: the acme dir
    # serves a nixpkgs minica self-signed fallback before the first successful
    # LE run, which LAN clients trusting the bnuy CA root cannot verify.
    # data/assets/ssl holds the LE cert when valid, else a bnuy CA leaf, so the
    # host vhost and the mailcow containers always serve the same chain.
    services.nginx = {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.domain} = {
        serverName = cfg.domain;
        serverAliases = aliases;
        addSSL = true;
        sslCertificate = "${sslDir}/cert.pem";
        sslCertificateKey = "${sslDir}/key.pem";
        http2 = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        locations."/" = {
          proxyPass = "https://127.0.0.1:${toString cfg.httpsPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_ssl_verify off;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };
      # Port 80: ACME http-01 challenge + redirect to https.
      virtualHosts."${cfg.domain}-http" = {
        serverName = cfg.domain;
        serverAliases = aliases;
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

    security.acme = {
      acceptTerms = true;
      certs.${cfg.domain} = {
        email = cfg.email;
        group = "nginx";
        # http-01 served from this dir by the port-80 vhost (which uses
        # useACMEHost = cfg.domain). Set explicitly because the nginx module
        # only wires webroot itself for vhosts with enableACME = true.
        webroot = "/var/lib/acme/acme-challenge";
        # extraDomainNames intentionally left to the nginx module, which
        # merges serverAliases (all SAN + apex domains) into the cert.
      };
    };

    networking.firewall.allowedTCPPorts = [
      25
      465
      587 # smtp / smtps / submission
      110
      143 # pop3 / imap
      993
      995 # imaps / pop3s
      4190 # manage sieve
    ];

    # ---------------------------------------------------------------------
    # sops secrets (sopsFile set explicitly: pterodactyl module owns
    # sops.defaultSopsFile for this host).
    # ---------------------------------------------------------------------
    sops.secrets = {
      "mailcow/dbpass" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/dbroot" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/redispass" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/api_key" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/sogo_key" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/admin_password" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/watchdog_webhook" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
      "mailcow/backup_password" = {
        sopsFile = ./secrets.yaml;
        owner = "mailcow";
        mode = "0400";
      };
    }
    // lib.listToAttrs (
      map (
        mb:
        lib.nameValuePair "mailcow/${mb.passwordSopsKey}" {
          sopsFile = ./secrets.yaml;
          owner = "mailcow";
          mode = "0400";
        }
      ) cfg.mailboxes
    )
    // {
      # mailcow-certs reads the step-ca password for the offline CA fallback.
      # owner must stay root: systemd LoadCredentials (how step-ca receives it)
      # only loads files owned by root or the service user. group=mailcow +
      # 0440 gives the mailcow user read access via group membership.
      "step-ca/password" = {
        group = "mailcow";
        mode = "0440";
      };
    };

    # Same keyring the pterodactyl module uses; keep set in case it is disabled.
    sops.age.sshKeyPaths = lib.mkDefault [ ];
    sops.age.keyFile = lib.mkDefault "/var/lib/sops-nix/keys.txt";

    # ---------------------------------------------------------------------
    # mailcow-seed: bootstrap cert so nginx/postfix/dovecot can start before
    # LE is available. Replaced by mailcow-certs shortly after.
    # ---------------------------------------------------------------------
    systemd.services.mailcow-seed = {
      description = "Mailcow: write bootstrap TLS cert";
      before = [ "mailcow-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "mailcow";
        Group = "mailcow";
      };
      path = [
        pkgs.openssl
        pkgs.coreutils
      ];
      script = ''
        mkdir -p ${sslDir}
        # dhparams.pem is generated once by mailcow's generate_config.sh
        # (cp -n from data/assets/ssl-example); after the first setup rsync
        # only cert.pem/key.pem get (re)written by mailcow-certs, so dovecot's
        # ssl_dh directive breaks if this dir is ever wiped. Copy it here too.
        if [ ! -f ${sslDir}/dhparams.pem ] && [ -f ${cfg.dataDir}/data/assets/ssl-example/dhparams.pem ]; then
          cp -n ${cfg.dataDir}/data/assets/ssl-example/dhparams.pem ${sslDir}/dhparams.pem
        fi
        if [ ! -f ${sslDir}/key.pem ]; then
          openssl req -x509 -newkey rsa:4096 \
            -keyout ${sslDir}/key.pem -out ${sslDir}/cert.pem \
            -days 365 -nodes -sha256 \
            -subj "/CN=${cfg.domain}" \
            -addext "subjectAltName=DNS:${cfg.domain},${
              lib.concatMapStringsSep "," (s: "DNS:${s}") sanNames
            }"
          chmod 644 ${sslDir}/cert.pem ${sslDir}/key.pem
        fi
      '';
    };

    # ---------------------------------------------------------------------
    # mailcow-setup: rsync pinned repo, render write-once mailcow.conf, up -d.
    # ---------------------------------------------------------------------
    systemd.services.mailcow-setup = {
      description = "Mailcow: install repo, config, start stack";
      after = [
        "docker.service"
        "sops-nix.service"
        "mailcow-seed.service"
      ];
      wants = [
        "docker.service"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.docker
        pkgs.rsync
        pkgs.openssl
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = cfg.dataDir;
        TimeoutStartSec = 0;
        # docker compose needs a writable HOME for its CLI config.
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        User = "mailcow";
        Group = "mailcow";
        # Containers chown files/dirs inside data/ to their own container
        # uids at runtime; the mailcow user then can't write into those
        # dirs on the next rsync (EPERM/exit 23). "+" = run as root even
        # though User=mailcow, restoring write access before the sync.
        ExecStartPre = "+${pkgs.coreutils}/bin/chown -R mailcow:mailcow ${cfg.dataDir}";
      };
      script = ''
        set -eu
        mkdir -p ${cfg.dataDir}
        # Copy the pinned checkout. data/ is live state: rsync keeps repo
        # files that change, never deletes files that mailcow generates at
        # runtime (no --delete on data/), and mailcow.conf is preserved.
        # No attribute preservation (-rl, not -a): containers chown files
        # inside data/ to root at runtime, and mailcow cannot chmod/chown
        # those (rsync -a aborts with EPERM/exit 23). Content-only sync.
        rsync -rl \
          --exclude mailcow.conf \
          --exclude .env \
          ${mailcowSrc}/ ${cfg.dataDir}/
        # rsync -rl gives default perms (0755/0644); the first -a run may
        # have left read-only store perms on the tree. || true: some files
        # are root-owned (container-written) and chmod on those is EPERM.
        chmod -R u+w ${cfg.dataDir} || true
        # ponytail: the Docker bridge network is IPv4-only (daemon ipv6 off),
        # so unbound can't reach v6 roots and SERVFAILs its own healthcheck.
        # Flip do-ip6 off in the shipped conf. Upgrade path: enable IPv6 on
        # the docker0 network, then drop this sed.
        sed -i 's/do-ip6: yes/do-ip6: no/' ${cfg.dataDir}/data/conf/unbound/unbound.conf
        ln -sfn mailcow.conf ${cfg.dataDir}/.env

        # Write-once config: mailcow.conf drives the MySQL/Redis passwords, so
        # it must NEVER be rewritten from rotated sops values after first boot.
        if [ ! -f ${cfg.dataDir}/mailcow.conf ]; then
          cat > ${cfg.dataDir}/mailcow.conf <<EOF
        # Rendered once by mailcow-setup from sops secrets.
        # ponytail: write-once on purpose - changing DBPASS/DBROOT/REDISPASS here
        # would desync the existing MariaDB/Redis data. Edit in place to change.
        MAILCOW_HOSTNAME=${cfg.domain}
        MAILCOW_PASS_SCHEME=BLF-CRYPT
        DBNAME=mailcow
        DBUSER=mailcow
        DBPASS=$(cat ${secret "dbpass"})
        DBROOT=$(cat ${secret "dbroot"})
        REDISPASS=$(cat ${secret "redispass"})
        HTTP_PORT=${toString cfg.httpPort}
        HTTP_BIND=127.0.0.1
        HTTPS_PORT=${toString cfg.httpsPort}
        HTTPS_BIND=127.0.0.1
        HTTP_REDIRECT=y
        SMTP_PORT=25
        SMTPS_PORT=465
        SUBMISSION_PORT=587
        IMAP_PORT=143
        IMAPS_PORT=993
        POP_PORT=110
        POPS_PORT=995
        SIEVE_PORT=4190
        DOVEADM_PORT=127.0.0.1:19991
        SQL_PORT=127.0.0.1:13306
        REDIS_PORT=127.0.0.1:7654
        TZ=America/New_York
        COMPOSE_PROJECT_NAME=${project}
        DOCKER_COMPOSE_VERSION=native
        ACL_ANYONE=disallow
        MAILDIR_GC_TIME=7200
        ADDITIONAL_SAN=
        AUTODISCOVER_SAN=y
        ADDITIONAL_SERVER_NAMES=
        # Certificates are managed by the host (LE with step-ca fallback) and
        # copied into data/assets/ssl by mailcow-certs; keep acme-mailcow inert.
        SKIP_LETS_ENCRYPT=y
        ACME_DNS_CHALLENGE=n
        ACME_DNS_PROVIDER=dns_xxx
        ACME_ACCOUNT_EMAIL=${cfg.email}
        ENABLE_SSL_SNI=n
        SKIP_UNBOUND_HEALTHCHECK=n
        SKIP_CLAMD=n
        SKIP_OLEFY=n
        SKIP_SOGO=n
        SKIP_FTS=n
        FTS_HEAP=128
        FTS_PROCS=1
        ALLOW_ADMIN_EMAIL_LOGIN=n
        USE_WATCHDOG=y
        WATCHDOG_NOTIFY_WEBHOOK=$(cat ${secret "watchdog_webhook"})
        WATCHDOG_NOTIFY_BAN=y
        WATCHDOG_NOTIFY_START=y
        WATCHDOG_EXTERNAL_CHECKS=y
        WATCHDOG_VERBOSE=n
        LOG_LINES=9999
        IPV4_NETWORK=172.22.1
        IPV6_NETWORK=fd4d:6169:6c63:6f77::/64
        API_KEY=$(cat ${secret "api_key"})
        API_KEY_READ_ONLY=invalid
        API_ALLOW_FROM=127.0.0.1
        MAILDIR_SUB=Maildir
        SOGO_EXPIRE_SESSION=480
        SOGO_URL_ENCRYPTION_KEY=$(cat ${secret "sogo_key"})
        DOVECOT_MASTER_USER=
        DOVECOT_MASTER_PASS=
        WEBAUTHN_ONLY_TRUSTED_VENDORS=n
        SPAMHAUS_DQS_KEY=
        ENABLE_IPV6=false
        DISABLE_NETFILTER_ISOLATION_RULE=n
        EOF
          chmod 600 ${cfg.dataDir}/mailcow.conf
        fi

        # Compose substitutes \$VAR from .env (the symlink above).
        cd ${cfg.dataDir}
        docker compose -p ${project} up -d
      '';
    };

    # ---------------------------------------------------------------------
    # mailcow-certs: keep data/assets/ssl/cert.pem + key.pem fresh.
    # Preferred: host LE cert (via acme-mail.bnuy.dev). Fallback: local
    # step-ca (10-day certs) when LE is missing/expiring, so TLS stays valid
    # even if port 80/DNS are not yet public. Reloads nginx + restarts
    # postfix/dovecot only when the cert actually changes.
    # ---------------------------------------------------------------------
    systemd.services.mailcow-certs = {
      description = "Mailcow: sync TLS cert from host (LE, step-ca fallback)";
      after = [
        "mailcow-setup.service"
        "acme-${cfg.domain}.service"
        "sops-nix.service"
      ];
      wants = [
        "mailcow-setup.service"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.docker
        pkgs.openssl
        pkgs.step-cli
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        WorkingDirectory = cfg.dataDir;
        TimeoutStartSec = 0;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        User = "mailcow";
        Group = "mailcow";
        # The host nginx mail vhost reads cert.pem/key.pem from data/assets/ssl,
        # so it must reload whenever mailcow-certs swaps the cert. "+" runs as
        # root even though the unit drops to User=mailcow for its main script.
        ExecStartPost = "+${pkgs.systemd}/bin/systemctl reload nginx.service";
      };
      script = ''
        set -eu
        mkdir -p ${sslDir}
        SRC_CERT=/dev/null
        SRC_KEY=/dev/null

        # Preferred: real LE cert (acme-success marker means LE has actually
        # run at least once; before that the acme dir holds a nixpkgs minica
        # self-signed fallback, which LAN clients can't verify) valid for
        # another 21 days.
        if [ -f ${acmeDir}/acme-success ] \
           && [ -f ${leCert} ] && [ -f ${leKey} ] \
           && openssl x509 -checkend $((21 * 86400)) -noout -in ${leCert} 2>/dev/null; then
          SRC_CERT=${leCert}
          SRC_KEY=${leKey}
        else
          # Fallback: issue a 10-day cert from the local step-ca.
          ${pkgs.step-cli}/bin/step ca certificate \
            --ca-url https://127.0.0.1:9000 \
            --root ${../step-ca/root_ca.crt} \
            --provisioner admin \
            --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
            ${
              lib.concatMapStringsSep " " (s: "--san ${s}") ([ cfg.domain ] ++ sanNames ++ cfg.mailDomains)
            } \
            ${cfg.domain} /tmp/mailcow-cert.pem /tmp/mailcow-key.pem
          SRC_CERT=/tmp/mailcow-cert.pem
          SRC_KEY=/tmp/mailcow-key.pem
        fi

        if ! cmp -s "$SRC_CERT" ${sslDir}/cert.pem \
           || ! cmp -s "$SRC_KEY" ${sslDir}/key.pem; then
          install -m 0644 "$SRC_CERT" ${sslDir}/cert.pem
          install -m 0644 "$SRC_KEY" ${sslDir}/key.pem
          # nginx can reload; postfix/dovecot take the new cert on restart
          # (same approach as mailcow's own reload-configurations.sh).
          cd ${cfg.dataDir}
          for svc in nginx-mailcow postfix-mailcow dovecot-mailcow; do
            docker compose -p ${project} restart "$svc" >/dev/null 2>&1 || true
          done
        fi
      '';
    };

    systemd.timers.mailcow-certs = {
      description = "Mailcow: daily cert sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # ---------------------------------------------------------------------
    # mailcow-provision: first-boot setup of admin password, mail domain and
    # mailboxes (via the mailcow API), then prints the DKIM DNS record.
    # Idempotent: SQL/API calls only run when the objects are missing.
    # ---------------------------------------------------------------------
    systemd.services.mailcow-provision = {
      description = "Mailcow: provision admin, domain, mailboxes";
      after = [
        "mailcow-setup.service"
        "sops-nix.service"
      ];
      wants = [
        "mailcow-setup.service"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.docker
        pkgs.curl
        pkgs.jq
        pkgs.gnused
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 15;
        TimeoutStartSec = 0;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        User = "mailcow";
        Group = "mailcow";
      };
      script = ''
        set -eu
        # Wait for the web UI to come up.
        API=https://127.0.0.1:${toString cfg.httpsPort}/api/v1
        for i in $(seq 1 120); do
          curl -sfk "$API" >/dev/null 2>&1 && break
          sleep 5
        done

        ADMIN_PW=$(cat ${secret "admin_password"})
        API_KEY=$(cat ${secret "api_key"})
        DBUSER=mailcow
        DBPASS=$(cat ${secret "dbpass"})
        DBNAME=mailcow

        # Admin account (password hashed like mailcow-reset-admin.sh).
        if [ "$(docker exec ${project}-mysql-mailcow-1 mysql -u"$DBUSER" -p"$DBPASS" "$DBNAME" -N -e "SELECT COUNT(*) FROM admin WHERE username='admin'" 2>/dev/null || echo 1)" = "0" ]; then
          HASH=$(docker exec ${project}-dovecot-mailcow-1 doveadm pw -s SSHA256 -p "$ADMIN_PW" | tr -d '\r')
          docker exec ${project}-mysql-mailcow-1 mysql -u"$DBUSER" -p"$DBPASS" "$DBNAME" \
            -e "DELETE FROM tfa WHERE username='admin'; INSERT INTO admin (username, password, superadmin, active) VALUES ('admin', '$HASH', 1, 1);"
        fi

        # Domain + DKIM keys (auto-generated on domain add).
        curl -sfk -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
          -d '{"domain":"${toString cfg.mailDomains}","aliases":20,"mailboxes":20,"defquota":10,"maxquota":10,"quota":100,"active":1,"key_size":2048,"dkim_selector":"dkim"}' \
          "$API/add/domain" >/dev/null 2>&1 || true

        # Mailboxes.
        ${lib.concatMapStringsSep "\n" (mb: ''
          MB_PW=$(cat ${secret mb.passwordSopsKey})
          if ! curl -sfk -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
            -d "$(jq -nc --arg user '${mb.address}' --arg local '${builtins.head (lib.splitString "@" mb.address)}' --arg domain '${lib.last (lib.splitString "@" mb.address)}' --arg name '${mb.name}' --arg quota '${toString mb.quota}' --arg password "$MB_PW" '{user_name:$user,local_part:$local,domain:$domain,name:$name,quota:$quota,password:$password,active:"1",force_pw_update:"0",tls_enforce_in:"1",tls_enforce_out:"1"}')" \
            "$API/add/mailbox" | grep -q '"type":"success"' 2>/dev/null; then
            : # mailbox exists or API n/a; never fatal
          fi
        '') cfg.mailboxes}

        # Print the DKIM DNS record (selector stored in redis by mailcow).
        DKIM=$(docker exec ${project}-redis-mailcow-1 redis-cli -a "$(cat ${secret "redispass"})" --no-auth-warning HGET DKIM_PUB_KEYS ${builtins.head cfg.mailDomains} 2>/dev/null || true)
        if [ -n "$DKIM" ]; then
          echo "DKIM DNS record for ${builtins.head cfg.mailDomains}:"
          echo "  dkim._domainkey.${builtins.head cfg.mailDomains} TXT  \"v=DKIM1;k=rsa;t=s;s=email;p=$DKIM\""
        fi
      '';
    };

    # mailcow-backup needs /var/backups to exist before its mount namespace
    # (ReadWritePaths) is set up, or the unit fails at NAMESPACE.
    systemd.tmpfiles.rules = [ "d /var/backups 0755 root root -" ];

    # ---------------------------------------------------------------------
    # mailcow-backup: nightly restic of config, named volumes and a consistent
    # MySQL dump. Repo in /var/backups/mailcow/repo, password via sops.
    # ponytail: must stay User=root - it ls/restic-reads the named volumes
    # under /var/lib/docker/volumes (0700 root), which no group membership
    # grants. Non-root snapshotting would need restic-in-a-container mounts.
    # ---------------------------------------------------------------------
    systemd.services.mailcow-backup = {
      description = "Mailcow: restic backup";
      after = [
        "mailcow-setup.service"
        "sops-nix.service"
      ];
      wants = [ "sops-nix.service" ];
      path = [
        pkgs.restic
        pkgs.docker
        pkgs.gzip
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = cfg.dataDir;
        TimeoutStartSec = 0;
        ReadWritePaths = [
          cfg.dataDir
          "/var/backups"
        ];
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      script = ''
        set -eu
        mkdir -p /var/backups/mailcow/mysql /var/backups/mailcow/repo
        export RESTIC_PASSWORD=$(cat ${secret "backup_password"})

        # Consistent DB dump (mysql container root password == DBROOT).
        docker exec ${project}-mysql-mailcow-1 mariadb-dump \
          --all-databases --single-transaction --routines --triggers \
          -uroot -p"$(cat ${secret "dbroot"})" 2>/dev/null \
          | gzip -9 > /var/backups/mailcow/mysql/dump.sql.gz

        # Redis durability before snapshotting its volume.
        docker exec ${project}-redis-mailcow-1 \
          redis-cli -a "$(cat ${secret "redispass"})" --no-auth-warning save >/dev/null 2>&1 || true

        # Init repo once, then back up config + named volumes + dump.
        if ! restic snapshots >/dev/null 2>&1; then
          restic init
        fi
        {
          echo /var/lib/mailcow
          echo /var/backups/mailcow/mysql
          ls -d /var/lib/docker/volumes/${project}_*/_data 2>/dev/null || true
        } > /var/backups/mailcow/backup.list
        restic backup --files-from /var/backups/mailcow/backup.list
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
      '';
    };

    systemd.timers.mailcow-backup = {
      description = "Mailcow: nightly backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 12:00:00";
        Persistent = true;
      };
    };
  };
}
