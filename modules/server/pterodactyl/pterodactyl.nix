{
  config,
  pkgs,
  lib,
  networkingHostname,
  ...
}:

let
  cfg = config.services.pterodactyl;

  php = pkgs.php83.withExtensions ({ enabled, all }: with all; enabled ++ [
    bcmath
    gd
    pdo_mysql
    posix
    zip
  ]);

  wings = pkgs.stdenv.mkDerivation {
    pname = "wings";
    version = "1.13.0";
    src = pkgs.fetchurl {
      url = "https://github.com/pterodactyl/wings/releases/download/v${lib.removePrefix "v" "v1.13.0"}/wings_linux_amd64";
      hash = "sha256-knszEZGNZvG/4J/lfPKb54Y0T1E4QLLy9HL0I94u+N4=";
    };
    dontUnpack = true;
    installPhase = ''
      install -m755 -D $src $out/bin/wings
    '';
  };
in
{
  options.services.pterodactyl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Pterodactyl game server panel and Wings daemon";
    };

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

    useACME = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Let's Encrypt via ACME (requires a real public domain pointed at this server)";
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

    wingsHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "HTTP port for Wings daemon (game server allocations)";
    };

    wingsSftpPort = lib.mkOption {
      type = lib.types.port;
      default = 2022;
      description = "SFTP port for Wings daemon";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.pterodactyl = {
      isSystemUser = true;
      group = "pterodactyl";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.pterodactyl = { };
    users.users.nginx.extraGroups = [ "pterodactyl" ];

    systemd.tmpfiles.settings."pterodactyl-data" = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
        z = {
          mode = "0750";
          user = "pterodactyl";
          group = "pterodactyl";
        };
      };
    };

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      dataDir = "/var/lib/mysql-pterodactyl";
      ensureDatabases = [ cfg.dbName ];
      ensureUsers = [{
        name = cfg.dbUser;
        ensurePermissions = { "${cfg.dbName}.*" = "ALL PRIVILEGES"; };
      }];
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

    systemd.services.pterodactyl-ssl-cert = {
      description = "Generate self-signed SSL cert for Pterodactyl";
      before = [ "nginx.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /var/lib/pterodactyl/ssl
        if [ ! -f /var/lib/pterodactyl/ssl/key.pem ]; then
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
            -keyout /var/lib/pterodactyl/ssl/key.pem \
            -out /var/lib/pterodactyl/ssl/cert.pem \
            -days 3650 -nodes \
            -subj "/CN=${cfg.domain}" \
            -addext "subjectAltName=DNS:${cfg.domain},IP:${cfg.listenIP}"
        fi
        chmod 644 /var/lib/pterodactyl/ssl/cert.pem
        chmod 640 /var/lib/pterodactyl/ssl/key.pem
        chown root:nginx /var/lib/pterodactyl/ssl/key.pem /var/lib/pterodactyl/ssl/cert.pem
      '';
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        root = "${cfg.dataDir}/public";
        extraConfig = "index index.php;";
        addSSL = true;
        sslCertificate = "/var/lib/pterodactyl/ssl/cert.pem";
        sslCertificateKey = "/var/lib/pterodactyl/ssl/key.pem";
        listen = [
          {
            addr = cfg.listenIP;
            port = cfg.panelPort;
            ssl = true;
          }
        ];
        locations."/" = {
          tryFiles = "$uri $uri/ /index.php?$query_string";
        };
        locations."~ \.php$" = {
          extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.pterodactyl.socket};
            fastcgi_index index.php;
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
          '';
        };
        locations."~ /\\." = {
          extraConfig = "deny all;";
        };
        locations."/.well-known" = lib.mkIf cfg.useACME {
          extraConfig = "allow all;";
        };
      };

      virtualHosts."${cfg.domain}-http" = {
        listen = [
          {
            addr = cfg.listenIP;
            port = 8080;
          }
        ];
        locations."/" = {
          extraConfig = "return 301 https://$host:${toString cfg.panelPort}$request_uri;";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      8080
      cfg.panelPort
      cfg.wingsHttpPort
      cfg.wingsSftpPort
    ];

    systemd.services.pterodactyl-set-db-password = {
      description = "Set Pterodactyl database user password from SOPS";
      after = [ "mysql.service" "sops-nix.service" ];
      wants = [ "mysql.service" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.mariadb ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
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
      };
      script = ''
        DB_PASS=$(cat ${config.sops.secrets."pterodactyl/db_password".path})
        APP_KEY=$(cat ${config.sops.secrets."pterodactyl/app_key".path})

        mkdir -p "${cfg.dataDir}"
        cat > "${cfg.dataDir}/.env" << EOF
APP_ENV=production
APP_DEBUG=false
APP_KEY=$APP_KEY
APP_URL=https://${cfg.listenIP}:${toString cfg.panelPort}

DB_DATABASE=${cfg.dbName}
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=${cfg.dbUser}
DB_PASSWORD=$DB_PASS

REDIS_HOST=localhost
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOF

        chmod 750 "${cfg.dataDir}"
        chmod 755 "${cfg.dataDir}/public"
        chown pterodactyl:pterodactyl "${cfg.dataDir}/.env"
      '';
    };

    systemd.services.pteroq = {
      description = "Pterodactyl Queue Worker";
      after = [
        "mysql.service"
        "redis-pterodactyl.service"
        "pterodactyl-env.service"
      ];
      wants = [ "mysql.service" "redis-pterodactyl.service" "pterodactyl-env.service" ];
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
      };
    };

    services.cron = {
      enable = true;
      systemCronJobs = [
        "* * * * * pterodactyl ${php}/bin/php ${cfg.dataDir}/artisan schedule:run >> /dev/null 2>&1"
      ];
    };

    systemd.services.wings = {
      description = "Pterodactyl Wings Daemon";
      after = [ "docker.service" "sops-nix.service" ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ wings ];
      serviceConfig = {
        User = "root";
        WorkingDirectory = "/etc/pterodactyl";
        ExecStart = "${wings}/bin/wings";
        Restart = "always";
        RestartSec = 10;
      };
      preStart = ''
        mkdir -p /etc/pterodactyl
      '';
    };

    services.technitium = lib.mkIf cfg.configureDNS {
      enable = true;
      localDomain = "${networkingHostname}.local";
      listenAddress = cfg.listenIP;
    };

    sops.defaultSopsFile = ./secrets.yaml;
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.secrets."pterodactyl/db_password" = {
      owner = "pterodactyl";
      mode = "0440";
    };

    sops.secrets."pterodactyl/app_key" = {
      owner = "pterodactyl";
      mode = "0440";
    };
  };
}
