{
  config,
  pkgs,
  lib,
  networkingHostname,
  ...
}:

let
  cfg = config.services.pterodactyl;

  # https://domain[:8443] — omit the port when it's the default 443
  appUrl = "https://${cfg.domain}${lib.optionalString (cfg.urlPort != 443) ":${toString cfg.urlPort}"}";
  httpRedirect = "https://$host${lib.optionalString (cfg.urlPort != 443) ":${toString cfg.urlPort}"}$request_uri";

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
    { addr = "0.0.0.0"; port = 443; ssl = true; }
    { addr = "0.0.0.0"; port = cfg.httpsPort; ssl = true; }
  ];
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

    configureDNS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-configure Technitium DNS to resolve *.hostname.local to this server";
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
      # This is the origin cert Cloudflare validates against (Full-strict) for
      # the tunneled minecraft.bnuy.dev traffic.
      virtualHosts.${cfg.domain} = {
        root = "${cfg.dataDir}/public";
        extraConfig = "index index.php;";
        enableACME = true;
        addSSL = true;
        listen = panelSslListen;
        locations = panelLocations;
      };

      # LAN/private vhost: reach the panel at https://${cfg.listenIP} with a
      # step-ca-issued cert (no browser warning once the root is installed).
      # Also the endpoint Wings uses for its panel connection (remote).
      virtualHosts.${cfg.listenIP} = {
        root = "${cfg.dataDir}/public";
        extraConfig = "index index.php;";
        addSSL = true;
        sslCertificate = cfg.lanCertFile;
        sslCertificateKey = cfg.lanCertKey;
        default = true;
        listen = panelSslListen;
        locations = panelLocations;
      };

      # Port 80: redirect to https://$host:<httpsPort> and serve the ACME
      # http-01 challenge for the same Let's Encrypt cert (via useACMEHost).
      virtualHosts."${cfg.domain}-http" = {
        listen = [
          { addr = "0.0.0.0"; port = 80; }
        ];
        useACMEHost = cfg.domain;
        locations."/" = {
          extraConfig = "return 301 ${httpRedirect};";
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      cfg.httpsPort
      cfg.wingsHttpPort
      cfg.wingsSftpPort
    ];
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

                mkdir -p "${cfg.dataDir}"
                cat > "${cfg.dataDir}/.env" << EOF
        APP_ENV=production
        APP_DEBUG=false
        APP_KEY=$APP_KEY
        APP_URL=${appUrl}
        # Self-signed (no Let's Encrypt): replace the line above with:
        # APP_URL=https://${cfg.listenIP}:${toString cfg.panelPort}

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
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token \"$(cat ${config.sops.secrets."pterodactyl/cloudflared_token".path})\"'";
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
      path = [ php pkgs.mariadb ];
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
        # LAN TLS cert (step-ca-issued): both nginx and wings need to read it.
        # Both are in the pterodactyl group; enforce ownership/perms each boot.
        chown root:pterodactyl ${cfg.lanCertFile} ${cfg.lanCertKey} 2>/dev/null || true
        chmod 0640 ${cfg.lanCertFile} ${cfg.lanCertKey} 2>/dev/null || true
        # If a Wings config exists (placed/downloaded from the panel or created
        # by `wings configure`), make sure system.data points at gamesDir so all
        # game server files land under ${cfg.gamesDir}/<server-uuid>.
        if [[ -f /etc/pterodactyl/config.yml ]]; then
          if grep -q '^  data:' /etc/pterodactyl/config.yml; then
            sed -i 's#^  data:.*#  data: ${cfg.gamesDir}#' /etc/pterodactyl/config.yml
          fi
        fi
      '';
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
        ReadWritePaths = [ "/etc/pterodactyl" cfg.gamesDir "/tmp" ];
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

    services.technitium = lib.mkIf cfg.configureDNS {
      enable = true;
      localDomain = "${networkingHostname}.local";
      listenAddress = cfg.listenIP;
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

    sops.secrets."pterodactyl/cloudflared_token" = lib.mkIf cfg.cloudflared.enable {
      owner = "pterodactyl";
      mode = "0400";
    };

    # Pin the tunnel origin to local nginx instead of the CF edge (loop).
    networking.extraHosts = lib.mkIf cfg.cloudflared.enable "127.0.0.1 ${cfg.domain}";
  };
}
