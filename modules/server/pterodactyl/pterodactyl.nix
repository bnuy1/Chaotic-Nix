{
  config,
  pkgs,
  lib,
  networkingHostname,
  ...
}:

let
  cfg = config.services.pterodactyl;

  # shared server plumbing (ssl/vhost/fence helpers); takes only {lib,pkgs}.
  tls = (import ../lib.nix) { inherit lib pkgs; };

  # The 403 landing-page bits (error_page + asset locations) for the default
  # 443 stub + any fence vhost (AGENTS posture 5: unknown Host gets the pretty
  # "access denied" page, never a real app).
  f403 = tls.fence403 { assetsDir = config.services."403".assetsDir; };

  # https://domain[:8443] — omit the port when it's the default 443
  appUrl = "https://${cfg.domain}${
    lib.optionalString (cfg.urlPort != 443) ":${toString cfg.urlPort}"
  }";
  httpRedirect = "https://$host${
    lib.optionalString (cfg.urlPort != 443) ":${toString cfg.urlPort}"
  }$request_uri";
  php = pkgs.php83.withExtensions (
    { enabled, all }:
    with all;
    enabled
    ++ [
      bcmath
      gd
      pdo_mysql
      posix
      zip
    ]
  );

  wings = pkgs.stdenv.mkDerivation {
    pname = "wings";
    version = "1.13.2";
    src = pkgs.fetchurl {
      url = "https://github.com/pterodactyl/wings/releases/download/v${lib.removePrefix "v" "v1.13.2"}/wings_linux_amd64";
      hash = "sha256-k+p9lSt7hHaCsJC94iRuZUPCo20QOo+TMpq7lKHDDqo=";
    };
    dontUnpack = true;
    installPhase = ''
      install -m755 -D $src $out/bin/wings
    '';
  };

  # Shared nginx locations for both the public FQDN vhost and the LAN IP vhost.
  panelLocations = {
    "/" = {
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };
    "~ \.php$" = {
      extraConfig = ''
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${config.services.phpfpm.pools.pterodactyl.socket};
        fastcgi_index index.php;
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
      '';
    };
    "~ /\\." = {
      extraConfig = "deny all;";
    };
  };

  # SSL listen directives shared by both panel vhosts (443 + cfg.httpsPort).
  panelSslListen = [
    {
      addr = "0.0.0.0";
      port = 443;
      ssl = true;
    }
    {
      addr = "0.0.0.0";
      port = cfg.httpsPort;
      ssl = true;
    }
  ];

  # Playtime leaderboard hologram + auto-rank (FancyHolograms/LuckPerms).
  # Substitutes the sops secret path into the checked-in bash script.
  mcLeaderboardScript = pkgs.writeShellScript "mc-leaderboard" (lib.replaceStrings
    [ "__MC_DB_PASS_FILE__" ]
    [ config.sops.secrets."pterodactyl/mc_db_password".path ]
    (builtins.readFile ./leaderboard-update.sh));

  backupDir = "/var/backups/pterodactyl";
in
{
  options.services.pterodactyl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Pterodactyl game server panel and Wings daemon";
    };
    # Please note this was attempted but not successfull, this is not a good example of good nixos code
    # I included technitium to potentially do this in the future >:3
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pterodactyl.${networkingHostname}.local";
      description = "Domain or IP for the Pterodactyl panel nginx vhost";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/pterodactyl";
      description = "Data directory for the panel files";
    };

    gamesDir = lib.mkOption {
      type = lib.types.str;
      default = "/games/pterodactyl";
      description = "Directory where Wings stores game server files (Wings config 'system.data', one subdir per server)";
    };

    dbName = lib.mkOption {
      type = lib.types.str;
      default = "pterodactyl";
      description = "MariaDB database name";
    };

    dbUser = lib.mkOption {
      type = lib.types.str;
      default = "pterodactyl";
      description = "MariaDB username";
    };

    listenIP = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address for the panel (used by dnsmasq and APP_URL). Set to LAN IP (e.g. 192.168.1.166) for network access";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "admin@${networkingHostname}.local";
      description = "Email for Let's Encrypt notifications";
    };

    panelPort = lib.mkOption {
      type = lib.types.port;
      default = 4433;
      description = "HTTPS port for the Pterodactyl panel";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = ''
        Public HTTPS port for the panel. Use a non-default port (e.g. 8443)
        when the edge router cannot forward 443. Port 443 is always kept for
        LAN access; http:// on port 80 redirects to this port.
      '';
    };

    urlPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = ''
        Port used in APP_URL and the http->https redirect. 443 normally (e.g.
        when Cloudflare terminates public traffic in front of the panel); set
        equal to httpsPort only when the panel is NOT behind a reverse proxy.
      '';
    };

    cloudflared = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable the Cloudflare Tunnel daemon for this domain. Uses a
          remotely-managed tunnel: the tunnel token is read from the SOPS
          secret "pterodactyl/cloudflared_token".
        '';
      };
    };

    wingsHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port for Wings daemon (game server allocations)";
    };

    wingsSftpPort = lib.mkOption {
      type = lib.types.port;
      default = 2022;
      description = "SFTP port for Wings daemon";
    };

    wingsProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 8084;
      description = "Nginx-proxied Wings API port (WebSocket). Browsers on a domain origin need this to avoid Private Network Access blocks on the direct 8080 port.";
    };

    # Cert served on the LAN vhost (https://listenIP) AND used by Wings for its
    # own API TLS. Issued by the local step-ca; must be readable by both nginx
    # and the pterodactyl user (both in group pterodactyl).
    lanCertFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pterodactyl/ssl/cert.pem";
      description = "TLS certificate for the LAN panel vhost + Wings API";
    };
    lanCertKey = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pterodactyl/ssl/key.pem";
      description = "TLS private key for the LAN panel vhost + Wings API";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.pterodactyl = {
      isSystemUser = true;
      group = "pterodactyl";
      home = cfg.dataDir;
      createHome = true;
      # homeMode defaults to "700", which clobbers /srv/pterodactyl to 0700 on
      # every nixos-rebuild switch and breaks nginx asset serving. 0750 keeps
      # the dir traversable for the nginx worker (member of group pterodactyl).
      homeMode = "750";
      extraGroups = [ "docker" ];
    };
    users.groups.pterodactyl = { };
    # nginx must traverse ${cfg.dataDir} to serve static assets; php-fpm
    # already runs as pterodactyl. Keeping the dir at 0750 (not world-readable).
    users.users.nginx.extraGroups = [ "pterodactyl" ];

    systemd.tmpfiles.settings."pterodactyl-data" = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
        Z = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
      };
      "${cfg.dataDir}/public" = {
        Z = {
          mode = "0755";
          user = "pterodactyl";
          group = "pterodactyl";
        };
      };
      "/etc/pterodactyl" = {
        d = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
      };
      "${cfg.gamesDir}" = {
        d = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
      };
      # nginx (uid 60, runs as User=nginx) must be able to read the LAN TLS
      # certs; they are generated as root:root 0640, so pin them to group nginx.
      "${cfg.dataDir}/ssl/cert.pem" = {
        z = {
          mode = "0640";
          user = "root";
          group = "nginx";
        };
      };
      "${cfg.dataDir}/ssl/key.pem" = {
        z = {
          mode = "0640";
          user = "root";
          group = "nginx";
        };
      };
    };

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      dataDir = "/var/lib/mysql-pterodactyl";
      ensureDatabases = [ cfg.dbName ];
      ensureUsers = [
        {
          name = cfg.dbUser;
          ensurePermissions = {
            "${cfg.dbName}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    systemd.tmpfiles.settings."pterodactyl-mysql" = {
      "/var/lib/mysql-pterodactyl" = {
        d = {
          mode = "0755";
          user = "mysql";
          group = "mysql";
        };
      };
    };

    services.redis.servers.pterodactyl = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
    };

    services.phpfpm.pools.pterodactyl = {
      user = "pterodactyl";
      group = "pterodactyl";
      phpPackage = php;
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 50;
        "pm.start_servers" = 5;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 15;
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
        "listen.mode" = "0660";
      };
    };

    # ------------------------------------------------------------------------
    # ALTERNATIVE: self-signed cert for LAN-only setups WITHOUT Let's Encrypt.
    # If you can't reach Let's Encrypt (no port 80 open to the internet), then:
    #   1. uncomment this service AND the "Self-signed (no Let's Encrypt)"
    #      blocks in services.nginx + APP_URL + firewall below, and
    #   2. remove enableACME/forceSSL + security.acme.
    #
    # systemd.services.pterodactyl-ssl-cert = {
    #   description = "Generate self-signed SSL cert for Pterodactyl";
    #   before = [ "nginx.service" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     StateDirectory = "pterodactyl";
    #     ProtectSystem = "strict";
    #     ReadWritePaths = [ "/var/lib/pterodactyl" ];
    #     PrivateTmp = true;
    #     NoNewPrivileges = true;
    #   };
    #   script = ''
    #     mkdir -p /var/lib/pterodactyl/ssl
    #     if [ ! -f /var/lib/pterodactyl/ssl/key.pem ]; then
    #       ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
    #         -keyout /var/lib/pterodactyl/ssl/key.pem \
    #         -out /var/lib/pterodactyl/ssl/cert.pem \
    #         -days 365 -nodes \
    #         -subj "/CN=${cfg.domain}" \
    #         -addext "subjectAltName=DNS:${cfg.domain},IP:${cfg.listenIP}"
    #     fi
    #     chmod 644 /var/lib/pterodactyl/ssl/cert.pem
    #     chmod 640 /var/lib/pterodactyl/ssl/key.pem
    #     chown root:nginx /var/lib/pterodactyl/ssl/key.pem /var/lib/pterodactyl/ssl/cert.pem
    #   '';
    # };
    # ------------------------------------------------------------------------

    services.nginx = {
      enable = true;

      # Public FQDN: Let's Encrypt via ACME, served on 443 AND cfg.httpsPort.
      # Only generated while the Cloudflare tunnel is enabled; when it's off
      # (VPN/LAN-only panel) the domain vhosts are omitted entirely so they
      # can't collide with the LAN IP vhost below (same name when
      # domain==listenIP).
      virtualHosts =
        lib.optionalAttrs cfg.cloudflared.enable {
          ${cfg.domain} = {
            root = "${cfg.dataDir}/public";
            extraConfig = "index index.php;";
            enableACME = true;
            addSSL = true;
            listen = panelSslListen;
            locations = panelLocations;
          };

          # Port 80: redirect to https://$host:<httpsPort> and serve the ACME
          # http-01 challenge for the same Let's Encrypt cert (via useACMEHost).
          "${cfg.domain}-http" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            useACMEHost = cfg.domain;
            locations."/" = {
              extraConfig = "return 301 ${httpRedirect};";
            };
          };
        }
        // lib.optionalAttrs (!cfg.cloudflared.enable) {
          # LAN domain vhost: reach the panel at https://${cfg.domain} with a
          # step-ca cert covering both the domain and the listen IP.  Works
          # alongside the IP vhost below so either URL is valid.
          ${cfg.domain} = {
            root = "${cfg.dataDir}/public";
            # Fenced to LAN + tailnet: wings dials this vhost from its own LAN
            # IP (192.168.2.3, in the allowlist) so the fence does not break it.
            extraConfig = "index index.php;\n${tls.vpnLanFence}";
            addSSL = true;
            sslCertificate = cfg.lanCertFile;
            sslCertificateKey = cfg.lanCertKey;
            listen = [
              {
                addr = "0.0.0.0";
                port = 443;
                ssl = true;
              }
            ];
            locations = panelLocations;
          };
        }
        // {
          # LAN/private vhost: reach the panel at https://${cfg.listenIP} with a
          # step-ca-issued cert (no browser warning once the root is installed).
          # Also the endpoint Wings uses for its panel connection (remote).
          # 443 only: 8443's default_server is headscale, and the panel stays
          # reachable by SNI on minecraft.bnuy.dev:8443.
          ${cfg.listenIP} = {
            root = "${cfg.dataDir}/public";
            extraConfig = "index index.php;\n${tls.vpnLanFence}";
            addSSL = true;
            sslCertificate = cfg.lanCertFile;
            sslCertificateKey = cfg.lanCertKey;
            listen = [
              {
                addr = "0.0.0.0";
                port = 443;
                ssl = true;
              }
            ];
            locations = panelLocations;
          };
        }
        // {
          # Default 443 server (AGENTS posture rule 5): unknown Host headers or
          # SNI — incl. the tunnel origin dialing localhost — fall through here.
          # Instead of a bare connection-close, serve the operator's 403 landing
          # (deny all → 403 → error_page /403.html). No real app is reachable.
          # The LAN cert is harmless: the landing page is all that's served.
          "pterodactyl-403-default" = {
            addSSL = true;
            sslCertificate = cfg.lanCertFile;
            sslCertificateKey = cfg.lanCertKey;
            default = true;
            listen = [
              {
                addr = "0.0.0.0";
                port = 443;
                ssl = true;
              }
            ];
            # deny all at server level 403s every request; combine with the
            # error_page (same extraConfig slot), and f403.locations serves the
            # assets (their `allow all` overrides the inherited deny).
            extraConfig = "deny all;\n${f403.extraConfig}";
            locations = f403.locations;
          };
        }
        // {
          # Wings API proxy: serves the daemon on cfg.wingsProxyPort so browsers
          # on a public-domain origin can reach Wings without being blocked by
          # Private Network Access restrictions (NS_ERROR_WEBSOCKET_CONNECTION_REFUSED).
          "pterodactyl-wings" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = cfg.wingsProxyPort;
                ssl = true;
              }
            ];
            addSSL = true;
            sslCertificate = cfg.lanCertFile;
            sslCertificateKey = cfg.lanCertKey;
            extraConfig = ''
              ${tls.vpnLanFence}
              location / {
                proxy_pass http://127.0.0.1:${toString cfg.wingsHttpPort};
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_read_timeout 3600s;
                proxy_send_timeout 3600s;
              }
            '';
          };
        };
    };

    security.acme = lib.mkIf cfg.cloudflared.enable {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      cfg.httpsPort
      # Minecraft (Velocity proxy)
      25565
    ];
    networking.firewall.allowedUDPPorts = [
      # Bedrock / Geyser
      19132
    ];
    # Wings proxy (8084) + SFTP (2022) are LAN/tailnet-only, so they are NOT in
    # allowedTCPPorts (that opens them to the whole WAN). Accept them only from
    # the trusted sources, and prepend so the accepts never land behind the
    # chain's later DROP.
    # ponytail: do NOT copy the technitium `-A INPUT` append pattern — it lands
    # after the DROP in some NixOS firewall revisions and becomes unreachable.
    networking.firewall.extraCommands =
      let
        subnets = lib.concatStringsSep "," [
          "192.168.1.0/24"
          "192.168.2.0/24"
          "100.64.0.0/10"
        ];
      in
      # ponytail: one --dport rule per port - this kernel's nft_compat can't
      # translate `-m multiport` (no xt_multiport module).
      ''
        for p in ${toString cfg.wingsProxyPort} ${toString cfg.wingsSftpPort}; do
          iptables -I INPUT 1 -p tcp --dport $p -s ${subnets} -j ACCEPT
        done
      '';
    # Self-signed (no Let's Encrypt): replace the ports above with:
    #   [ 8080 cfg.panelPort cfg.wingsHttpPort cfg.wingsSftpPort ]

    systemd.services.pterodactyl-set-db-password = {
      description = "Set Pterodactyl database user password from SOPS";
      after = [
        "mysql.service"
        "sops-nix.service"
      ];
      wants = [
        "mysql.service"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.mariadb ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectHome = true;
      };
      script = ''
        DB_PASS=$(cat ${config.sops.secrets."pterodactyl/db_password".path})
        mariadb -e "ALTER USER '${cfg.dbUser}'@'localhost' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;"
      '';
    };

    systemd.services.pterodactyl-env = {
      description = "Generate Pterodactyl panel .env from SOPS secrets";
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectHome = true;
      };
      script = ''
                DB_PASS=$(cat ${config.sops.secrets."pterodactyl/db_password".path})
                APP_KEY=$(cat ${config.sops.secrets."pterodactyl/app_key".path})
                SMTP_USER=$(cat ${config.sops.secrets."pterodactyl/smtp_username".path})
                SMTP_PASS=$(cat ${config.sops.secrets."pterodactyl/smtp_password".path})

                mkdir -p "${cfg.dataDir}"
                cat > "${cfg.dataDir}/.env" << EOF
        APP_ENV=production
        APP_DEBUG=false
        APP_KEY=$APP_KEY
        APP_URL=${appUrl}
        # Self-signed (no Let's Encrypt): replace the line above with:
        # APP_URL=https://${cfg.listenIP}:${toString cfg.panelPort}

        # Local-delivery mail via the host mailcow postfix submission (587,
        # STARTTLS). Recipients are @bnuy.dev inboxes; mail never leaves the box.
        MAIL_DRIVER=smtp
        MAIL_HOST=mail.bnuy.dev
        MAIL_PORT=587
        MAIL_USERNAME=$SMTP_USER
        MAIL_PASSWORD=$SMTP_PASS
        MAIL_ENCRYPTION=tls
        MAIL_FROM_ADDRESS=pterodactyl@bnuy.dev
        MAIL_FROM_NAME=Pterodactyl

        DB_DATABASE=${cfg.dbName}
        DB_HOST=localhost
        DB_PORT=3306
        DB_USERNAME=${cfg.dbUser}
        DB_PASSWORD=$DB_PASS

        REDIS_HOST=127.0.0.1
        REDIS_PORT=6379

        CACHE_DRIVER=redis
        SESSION_DRIVER=redis
        QUEUE_CONNECTION=redis
        RECAPTCHA_ENABLED=false
        EOF

                chmod 750 "${cfg.dataDir}"
                chmod 755 "${cfg.dataDir}/public"
                find "${cfg.dataDir}/public" -type d -exec chmod 755 {} \;
                find "${cfg.dataDir}/public" -type f -exec chmod 644 {} \;
                chmod 600 "${cfg.dataDir}/.env"
                chown pterodactyl:pterodactyl "${cfg.dataDir}/.env"
      '';
    };

    systemd.services.cloudflared = lib.mkIf cfg.cloudflared.enable {
      description = "Cloudflare Tunnel daemon (remotely-managed)";
      after = [
        "network-online.target"
        "sops-nix.service"
        "nginx.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "pterodactyl";
        Group = "pterodactyl";
        Restart = "on-failure";
        RestartSec = 5;
        # Remotely-managed tunnel: ingress is configured in the Cloudflare
        # Zero Trust dashboard; cloudflared only needs the tunnel token.
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token \"$(cat ${
          config.sops.secrets."pterodactyl/cloudflared_token".path
        })\"'";
      };
    };

    systemd.services.pteroq = {
      description = "Pterodactyl Queue Worker";
      after = [
        "mysql.service"
        "redis-pterodactyl.service"
        "pterodactyl-env.service"
      ];
      wants = [
        "mysql.service"
        "redis-pterodactyl.service"
        "pterodactyl-env.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ php ];
      serviceConfig = {
        User = "pterodactyl";
        Group = "pterodactyl";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${php}/bin/php ${cfg.dataDir}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3'";
        Restart = "on-failure";
        RestartSec = 10;
        ExecCondition = "${pkgs.bash}/bin/bash -c 'test -f ${cfg.dataDir}/artisan'";
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        MemoryDenyWriteExecute = true;
      };
    };

    services.cron = {
      enable = true;
      systemCronJobs = [
        "* * * * * pterodactyl ${php}/bin/php ${cfg.dataDir}/artisan schedule:run >> /dev/null 2>&1"
      ];
    };

    systemd.services.pterodactyl-migrate = {
      description = "Run Pterodactyl database migrations";
      after = [
        "mysql.service"
        "redis-pterodactyl.service"
        "pterodactyl-env.service"
        "pterodactyl-set-db-password.service"
      ];
      wants = [
        "mysql.service"
        "redis-pterodactyl.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        php
        pkgs.mariadb
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "pterodactyl";
        Group = "pterodactyl";
        WorkingDirectory = cfg.dataDir;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
      };
      script = ''
        for i in {1..10}; do
          ${php}/bin/php ${cfg.dataDir}/artisan migrate --force && exit 0
          sleep 2
        done
        exit 1
      '';
    };

    systemd.services.pterodactyl-wings-gamesdir = {
      description = "Point Wings game files at ${cfg.gamesDir}";
      before = [ "wings.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -o pterodactyl -g pterodactyl -m 0750 "${cfg.gamesDir}"
        # LAN TLS cert (step-ca-issued): nginx proxy and the panel read it.
        # Wings no longer uses TLS directly — the nginx proxy on
        # cfg.wingsProxyPort handles TLS termination.
        chown root:pterodactyl ${cfg.lanCertFile} ${cfg.lanCertKey} 2>/dev/null || true
        chmod 0640 ${cfg.lanCertFile} ${cfg.lanCertKey} 2>/dev/null || true
        # If a Wings config exists (placed/downloaded from the panel or created
        # by `wings configure`), make sure system.data points at gamesDir so all
        # game server files land under ${cfg.gamesDir}/<server-uuid>.
        if [[ -f /etc/pterodactyl/config.yml ]]; then
          if grep -q '^  data:' /etc/pterodactyl/config.yml; then
            sed -i 's#^  data:.*#  data: ${cfg.gamesDir}#' /etc/pterodactyl/config.yml
          fi
          # Wings listens on HTTP — TLS is handled by the nginx proxy.
          sed -i 's/^    cert: .*/    cert: ""/' /etc/pterodactyl/config.yml
          sed -i 's/^    key: .*/    key: ""/' /etc/pterodactyl/config.yml
          if grep -q '^  ssl:' /etc/pterodactyl/config.yml; then
            sed -i '/^  ssl:/,/    cert:/{s/    enabled: .*/    enabled: false/}' /etc/pterodactyl/config.yml
          fi
          # Allow WebSocket connections from the panel origin (LAN + domain; the
          # nginx vhosts are fenced anyway, so only these origins can reach the
          # wings proxy at all).
          sed -i 's/^allowed_origins: .*/allowed_origins:\n- https:\/\/${cfg.domain}/' /etc/pterodactyl/config.yml
          # Accept forwarded headers from the nginx proxy.
          sed -i 's/^trusted_proxies: .*/trusted_proxies:\n- 127.0.0.1/' /etc/pterodactyl/config.yml
          # Enable bind mounts for game-server backup containers.
          if ! grep -q '/games/pterodactyl' /etc/pterodactyl/config.yml 2>/dev/null; then
            sed -i '/^allowed_mounts:/,/^[^ -]/{/^  .*/d}' /etc/pterodactyl/config.yml
            sed -i '/^allowed_mounts:/a\- /games/pterodactyl\n- /games/backups\n- /run/secrets/pterodactyl' /etc/pterodactyl/config.yml
          fi
        fi
      '';
    };

    # Set SRC_DIR on mc-backup sidecar containers so they back up the
    # actual game data instead of the empty /data anonymous volume.
    # Wings only sets DATA_DIR; mc-backup reads SRC_DIR (defaulting to /data).
    systemd.services.pterodactyl-backup-srcdir = {
      description = "Inject SRC_DIR env var for mc-backup containers";
      after = [ "pterodactyl-migrate.service" ];
      wants = [ "pterodactyl-migrate.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.mariadb ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Register SRC_DIR on egg 8 (mc-backup sidecar egg).
        mariadb pterodactyl -e "
          INSERT IGNORE INTO egg_variables
            (egg_id, name, description, env_variable, default_value,
             user_viewable, user_editable, rules, created_at, updated_at)
          VALUES
            (8, 'Source Directory', 'Internal: mc-backup source path',
             'SRC_DIR', '/data', 0, 0, NULL, NOW(), NOW());
        " 2>/dev/null || true

        VAR_ID=$(mariadb pterodactyl -N -e \
          "SELECT id FROM egg_variables WHERE egg_id=8 AND env_variable='SRC_DIR' LIMIT 1;")

        # Set SRC_DIR on each backup server, pointing at its game server's data.
        # backup_uuid → game_uuid
        declare -A mapping=(
          ["04398364-2183-4ac1-9106-1736e70f245b"]="fd255e51-fba9-4a28-8b30-9b08f7959c6c"
          ["06a2a498-9a4f-4932-9e66-a6f195b7ee19"]="88f35865-2993-4936-9bd3-fd3e345317c4"
          ["38c04819-bb8e-41eb-af51-7fabac0a50d9"]="b4eaaa4d-2c34-46c5-ab25-6d974c108232"
          ["c5d749a8-916b-41b0-ab87-6526ed617e9a"]="a3f70d61-fc36-48e9-9013-10a2b48a726d"
        )
        for buuid in "''${!mapping[@]}"; do
          guuid="''${mapping[$buuid]}"
          sid=$(mariadb pterodactyl -N -e \
            "SELECT id FROM servers WHERE uuid='$buuid';" 2>/dev/null) || continue
          [ -z "$sid" ] && continue
          mariadb pterodactyl -e "
            INSERT INTO server_variables
              (server_id, variable_id, variable_value, created_at, updated_at)
            VALUES
              ($sid, $VAR_ID, '/games-src/$guuid', NOW(), NOW())
            ON DUPLICATE KEY UPDATE variable_value=VALUES(variable_value);
          "
        done
      '';
    };

    # Register itzg/minecraft-server variables as Pterodactyl panel options.
    # INSERT IGNORE makes this idempotent — safe to re-run on every boot.
    systemd.services.pterodactyl-egg-vars = {
      description = "Register itzg egg variables in Pterodactyl panel";
      after = [ "pterodactyl-migrate.service" ];
      wants = [ "pterodactyl-migrate.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.mariadb ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        E=
        mariadb pterodactyl -e "
          INSERT IGNORE INTO egg_variables
            (egg_id, name, description, env_variable, default_value,
             user_viewable, user_editable, rules, created_at, updated_at)
          VALUES
            (4, 'Difficulty', 'World difficulty level', 'DIFFICULTY', 'easy', 1, 1, 'required|in:peaceful,easy,normal,hard', NOW(), NOW()),
            (4, 'Game Mode', 'Default game mode for new players', 'MODE', 'survival', 1, 1, 'required|in:survival,creative,adventure,spectator', NOW(), NOW()),
            (4, 'Hardcore', 'Enable hardcore mode', 'HARDCORE', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'PVP', 'Allow player vs player combat', 'PVP', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Force Default Gamemode', 'Force the default gamemode on player join', 'FORCE_GAMEMODE', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Allow Flight', 'Allow flying in survival mode', 'ALLOW_FLIGHT', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Generate Structures', 'Generate villages, temples, and other structures', 'GENERATE_STRUCTURES', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Spawn Animals', 'Allow animal spawning', 'SPAWN_ANIMALS', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Spawn Monsters', 'Allow monster spawning', 'SPAWN_MONSTERS', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Spawn NPCs', 'Allow villager spawning', 'SPAWN_NPCS', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Command Blocks', 'Enable command blocks', 'ENABLE_COMMAND_BLOCK', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'World Seed', 'World generation seed (leave empty for random)', 'SEED', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'World Save Name', 'Name of the world save folder', 'LEVEL', 'world', 1, 1, 'required|string|max:50', NOW(), NOW()),
            (4, 'Level Type', 'World generation type (default, flat, largebiomes, amplified)', 'LEVEL_TYPE', 'default', 1, 1, 'required|string|max:20', NOW(), NOW()),
            (4, 'Spawn Protection', 'Spawn protection radius in blocks (0 to disable)', 'SPAWN_PROTECTION', '16', 1, 1, 'required|numeric|min:0|max:1000', NOW(), NOW()),
            (4, 'Max World Size', 'Maximum world radius in blocks', 'MAX_WORLD_SIZE', '29999984', 1, 1, 'required|numeric|min:1', NOW(), NOW()),
            (4, 'View Distance', 'Server view distance (3-32 chunks)', 'VIEW_DISTANCE', '10', 1, 1, 'required|numeric|min:2|max:32', NOW(), NOW()),
            (4, 'Simulation Distance', 'Simulation distance (3-32 chunks)', 'SIMULATION_DISTANCE', '10', 1, 1, 'required|numeric|min:2|max:32', NOW(), NOW()),
            (4, 'Player Idle Timeout', 'Kick idle players after N minutes (0 to disable)', 'PLAYER_IDLE_TIMEOUT', '0', 1, 1, 'required|numeric|min:0', NOW(), NOW()),
            (4, 'Watchdog Timeout', 'max-tick-time watchdog (-1 disables, required for autopause)', 'MAX_TICK_TIME', '-1', 0, 0, 'required|numeric', NOW(), NOW()),
            (4, 'Pause When Empty', 'Seconds before pausing when empty (1.21.2+, 0 to disable)', 'PAUSE_WHEN_EMPTY_SECONDS', '0', 1, 1, 'required|numeric|min:0', NOW(), NOW()),
            (4, 'Legacy Autopause', 'Enable itzg autopause for pre-1.21.2 versions', 'ENABLE_AUTOPAUSE', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Autopause Disconnect Timeout', 'Seconds before pausing after last disconnect', 'AUTOPAUSE_TIMEOUT_EST', '3600', 1, 1, 'required|numeric|min:1', NOW(), NOW()),
            (4, 'Autopause Initial Timeout', 'Seconds before pausing on fresh start', 'AUTOPAUSE_TIMEOUT_INIT', '600', 1, 1, 'required|numeric|min:1', NOW(), NOW()),
            (4, 'Autopause Knock Timeout', 'Seconds before pausing after port knock', 'AUTOPAUSE_TIMEOUT_KN', '120', 1, 1, 'required|numeric|min:1', NOW(), NOW()),
            (4, 'Resource Pack URL', 'URL to a resource pack to send to clients', 'RESOURCE_PACK', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'Resource Pack SHA1', 'SHA1 hash of the resource pack', 'RESOURCE_PACK_SHA1', '$E', 1, 1, 'nullable|string|max:40', NOW(), NOW()),
            (4, 'Resource Pack Enforce', 'Force clients to use the resource pack', 'RESOURCE_PACK_ENFORCE', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Resource Pack Prompt', 'Message shown when prompting clients to use the pack', 'RESOURCE_PACK_PROMPT', '$E', 1, 1, 'nullable|string|max:256', NOW(), NOW()),
            (4, 'Enable Whitelist', 'Enable whitelist management', 'ENABLE_WHITELIST', 'false', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Whitelist', 'Comma-separated list of usernames to whitelist', 'WHITELIST', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'Operators', 'Comma-separated list of usernames to op', 'OPS', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'Aikar JVM Flags', 'Use Aikar optimized JVM garbage collection flags', 'USE_AIKAR_FLAGS', 'true', 1, 1, 'required|string|in:true,false', NOW(), NOW()),
            (4, 'Custom JVM Options', 'Additional JVM arguments (space-delimited)', 'JVM_OPTS', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'JVM -XX Options', 'JVM -XX flags (space-delimited, precede -X options)', 'JVM_XX_OPTS', '$E', 1, 1, 'nullable|string', NOW(), NOW()),
            (4, 'Log Level', 'Root logger level', 'LOG_LEVEL', 'info', 1, 1, 'required|in:trace,debug,info,warn,error', NOW(), NOW()),
            (4, 'Shutdown Warning Delay', 'Seconds to announce before stopping the server', 'STOP_SERVER_ANNOUNCE_DELAY', '$E', 1, 1, 'nullable|numeric', NOW(), NOW()),
            (4, 'Shutdown Timeout', 'Seconds to wait for graceful shutdown', 'STOP_DURATION', '60', 1, 1, 'required|numeric|min:10', NOW(), NOW()),
            (4, 'Server Icon', 'URL or path to server icon (PNG, 64x64)', 'ICON', '$E', 1, 1, 'nullable|string', NOW(), NOW());
        " 2>/dev/null || true
      '';
    };

    systemd.services.pterodactyl-cert = {
      description = "Pterodactyl: issue LAN TLS cert from step-ca";
      wantedBy = [
        "nginx.service"
        "wings.service"
        "multi-user.target"
      ];
      after = [
        "step-ca.service"
        "sops-nix.service"
      ];
      before = [
        "nginx.service"
        "wings.service"
      ];
      path = [
        pkgs.openssl
        pkgs.coreutils
        pkgs.diffutils
        pkgs.step-cli
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        TimeoutStartSec = 0;
      };
      script = ''
        set -eu
        mkdir -p "$(dirname ${cfg.lanCertFile})"
        ${pkgs.step-cli}/bin/step ca certificate \
          --ca-url https://127.0.0.1:9000 \
          --root ${../step-ca/root_ca.crt} \
          --provisioner admin \
          --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
          --force \
          --san ${cfg.listenIP} \
          --san ${cfg.domain} \
          ${cfg.domain} /tmp/pterodactyl-cert.pem /tmp/pterodactyl-key.pem
        if ! cmp -s /tmp/pterodactyl-cert.pem ${cfg.lanCertFile} \
           || ! cmp -s /tmp/pterodactyl-key.pem ${cfg.lanCertKey}; then
          install -m 0640 /tmp/pterodactyl-cert.pem ${cfg.lanCertFile}
          install -m 0640 /tmp/pterodactyl-key.pem ${cfg.lanCertKey}
          chown root:pterodactyl ${cfg.lanCertFile} ${cfg.lanCertKey}
          systemctl is-active --quiet nginx.service \
            && systemctl reload nginx.service || true
        fi
      '';
    };

    systemd.timers.pterodactyl-cert = {
      description = "Pterodactyl: renew LAN TLS cert daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "pterodactyl-cert.service";
      };
    };

    systemd.services.wings = {
      description = "Pterodactyl Wings Daemon";
      after = [
        "docker.service"
        "sops-nix.service"
      ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ wings ];
      serviceConfig = {
        # Wings must run as root: install containers run as root and leave
        # root-owned files in the server directory, which wings chowns to the
        # container user during the pre-boot process. Running as "pterodactyl"
        # breaks that chown ("lchownat velocity.toml: permission denied").
        WorkingDirectory = "/etc/pterodactyl";
        ExecStart = "${wings}/bin/wings";
        Restart = "always";
        RestartSec = 10;
        ProtectSystem = "strict";
        # /tmp must be writable: Wings writes install scripts to
        # /tmp/pterodactyl and bind-mounts them into Docker containers.
        ReadWritePaths = [
          "/etc/pterodactyl"
          cfg.gamesDir
          "/tmp"
        ];
        # systemd-managed writable dirs (created+owned on start, writable even
        # under ProtectSystem=strict):
        #   /var/lib/pterodactyl  (ssl certs, archives, backups)
        #   /var/log/pterodactyl  (wings logs)
        #   /run/wings            (machine-id, tmpfs state)
        StateDirectory = "pterodactyl";
        LogsDirectory = "pterodactyl";
        RuntimeDirectory = "wings";
        # Must be false: Wings writes install scripts to /tmp/pterodactyl and
        # bind-mounts them into Docker containers. With PrivateTmp the docker
        # daemon cannot see that path ("bind source path does not exist").
        PrivateTmp = false;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
          "CAP_DAC_OVERRIDE"
          "CAP_FOWNER"
          "CAP_CHOWN"
          "CAP_SETUID"
          "CAP_SETGID"
        ];
        MemoryDenyWriteExecute = true;
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;
    sops.age.sshKeyPaths = [ ];
    sops.age.keyFile = "/var/lib/sops-nix/keys.txt";

    sops.secrets."pterodactyl/db_password" = {
      owner = "pterodactyl";
      mode = "0440";
    };

    sops.secrets."pterodactyl/app_key" = {
      owner = "pterodactyl";
      mode = "0440";
    };

    # Mailcow submission credential (SMTP_USERNAME/SMTP_PASSWORD in panel .env).
    # user = pterodactyl@bnuy.dev; password MUST equal mailcow/mailbox_pterodactyl.
    sops.secrets."pterodactyl/smtp_username" = {
      owner = "pterodactyl";
      mode = "0440";
    };

    sops.secrets."pterodactyl/smtp_password" = {
      owner = "pterodactyl";
      mode = "0440";
    };

    sops.secrets."pterodactyl/cloudflared_token" = lib.mkIf cfg.cloudflared.enable {
      owner = "pterodactyl";
      mode = "0400";
    };

    # Root password of the minecraft-db container; read by mc-leaderboard.
    sops.secrets."pterodactyl/mc_db_password" = {
      owner = "root";
      mode = "0400";
    };

    # Restic repo password for pterodactyl-backup (§6: never in a password
    # manager - it would be circular).  Mode 0444 so mc-backup containers
    # (running as pterodactyl uid) can read it via bind mount.
    sops.secrets."pterodactyl/backup_password" = {
      owner = "root";
      mode = "0444";
    };

    systemd.services.mc-leaderboard = {
      description = "Minecraft playtime leaderboard hologram + auto-rank";
      after = [ "docker.service" ];
      wants = [ "docker.service" ];
      path = [ pkgs.docker ];
      serviceConfig = {
        Type = "oneshot";
        # ponytail: rewrites holograms.yml wholesale, so holograms created
        # in-game are clobbered on the next run. Merge YAML if a second
        # hologram ever matters.
      };
      script = "${mcLeaderboardScript}";
    };

    systemd.timers.mc-leaderboard = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
        Unit = "mc-leaderboard.service";
      };
    };

    # ---------------------------------------------------------------------
    # Backup: nightly restic into this module's own repo under /var/backups
    # (per-module repo convention). Panel DB is native MariaDB; the
    # leaderboard DB lives in the dockerized minecraft-db container. Game
    # server files (/games/pterodactyl) are deliberately NOT backed up here:
    # the itzg containers run their own native restic backups.
    # ---------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d /var/backups 0755 root root -"
      "d ${backupDir} 0700 root root -"
      "d /var/cache/restic 0700 root root -"
      # Game-backup repos: mc-backup containers run as uid 994 (pterodactyl)
      # and need write on the per-server repos. 0770 root:pterodactyl (never
      # 0777); the Z line re-fixes dirs already created as 0777.
      "d /games/backups 0755 root root -"
      "d /games/backups/backup-velocity/repo 0770 root pterodactyl -"
      "Z /games/backups/backup-velocity/repo 0770 root pterodactyl -"
      "d /games/backups/backup-survival/repo 0770 root pterodactyl -"
      "Z /games/backups/backup-survival/repo 0770 root pterodactyl -"
      "d /games/backups/backup-creative/repo 0770 root pterodactyl -"
      "Z /games/backups/backup-creative/repo 0770 root pterodactyl -"
      "d /games/backups/backup-lobby/repo 0770 root pterodactyl -"
      "Z /games/backups/backup-lobby/repo 0770 root pterodactyl -"
    ];

    systemd.services.pterodactyl-backup = {
      description = "Pterodactyl: restic backup (panel DB, minecraft-db, panel dir)";
      after = [ "mysql.service" "docker.service" "sops-nix.service" ];
      wants = [ "docker.service" "sops-nix.service" ];
      path = [
        pkgs.restic
        pkgs.gzip
        pkgs.coreutils
        config.services.mysql.package
        pkgs.docker
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
        export RESTIC_PASSWORD=$(cat ${config.sops.secrets."pterodactyl/backup_password".path})
        # Bare `restic` has no default repo; point it at this module's repo.
        export RESTIC_REPOSITORY=${backupDir}/repo
        mkdir -p ${backupDir}/repo ${backupDir}/staging

        # Panel DB: root authenticates via the local unix socket.
        mysqldump --single-transaction --routines --triggers ${cfg.dbName} \
          | gzip -9 > ${backupDir}/staging/panel-db.sql.gz
        # Leaderboard DB (containerized mariadb, mailcow-style dump).
        docker exec minecraft-db mariadb-dump \
          --all-databases --single-transaction --routines --triggers \
          -uroot -p"$(cat ${config.sops.secrets."pterodactyl/mc_db_password".path})" 2>/dev/null \
          | gzip -9 > ${backupDir}/staging/minecraft-db.sql.gz

        if ! restic snapshots >/dev/null 2>&1; then
          restic init
        fi
        restic backup ${backupDir}/staging ${cfg.dataDir} --tag pterodactyl
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
      '';
    };

    systemd.timers.pterodactyl-backup = {
      description = "Pterodactyl: nightly backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
      };
    };

    # Pin the tunnel origin to local nginx instead of the CF edge (loop).
    networking.extraHosts = lib.mkIf cfg.cloudflared.enable "127.0.0.1 ${cfg.domain}";
  };
}
