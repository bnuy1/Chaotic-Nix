{
  config,
  pkgs,
  lib,
  ...
}:
let
  servers-nix = [
    "survival"
    "lab"
    "raina"
    "creative"
  ];
  servers = lib.concatStringsSep " " servers-nix; # Fucking work already
in
{
  environment = {
    shellAliases = {
      # Dumps logs to screen, then drops you into the RCON console indistinguishable from normal attaching sessions
      bnuy = "sudo docker logs minecraft-survival && sudo docker exec -it minecraft-survival rcon-cli";
      bnuy-lab = "sudo docker logs minecraft-lab && sudo docker exec -it minecraft-lab rcon-cli";
      bnuy-raina = "sudo docker logs minecraft-raina && sudo docker exec -it minecraft-raina rcon-cli";
      bnuy-creative = "sudo docker logs minecraft-creative && sudo docker exec -it minecraft-creative rcon-cli";
      bnuy-proxy = "sudo docker logs velocity && sudo docker exec -it velocity rcon-cli";
    };
  };

  # Docker network so that all the Minecraft docker containers can talk to each other over IPV4
  systemd.services.init-minecraft-network = {
    description = "Create Docker network for Minecraft";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.docker}/bin/docker network inspect mc-net >/dev/null 2>&1 || ${pkgs.docker}/bin/docker network create mc-net
    '';
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers.velocity = {
      image = "itzg/mc-proxy";
      ports = [
        "25565:25565"
        "19132:19132/udp"
      ]; # Only Velocity is exposed to the world
      #environmentFiles = [ config.sops.secrets."minecraft_env".path ];
      extraOptions = [ "--network=mc-net" ];
      environment = {
        TYPE = "VELOCITY";
        #ONLINE_MODE = "true";
        COPY_PLUGINS_SRC = "/staging-plugins";
        # Plugins SPIGOT auto download , but not all plugins support it)
        PLUGINS = " 
          https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity
          https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity";
        ENABLE_RCON = "true";
      };

      volumes = [
        "/var/lib/minecraft/velocity:/server"
        "/var/lib/minecraft/plugins/velocity:/staging-plugins:ro"
        "/etc/nixos/modules/development/minecraft-server/velocity.toml:/server/velocity.toml"
        "/var/lib/minecraft/velocity/forwarding.secret:/server/forwarding.secret"
      ];
    };

    containers.minecraft-survival = {
      image = "itzg/minecraft-server";
      # getting secrets to work is a bitch
      environmentFiles = [
        config.sops.secrets."minecraft_env".path
      ];

      # Attach to local docker network
      extraOptions = [
        "--network=mc-net" # internal connections
        "--add-host=host.docker.internal:host-gateway"
      ]; # Server Properties

      environment = {
        EULA = "true";
        TYPE = "PAPER";
        #VERSION = "26.1.2";
        VERSION = "1.21.11";
        #SERVER_IP = ""; # Bind to all interfaces inside the container
        INIT_MEMORY = "1G";
        MAX_MEMORY = "12G";
        SIMULATION_DISTANCE = "6";
        VIEW_DISTANCE = "32";
        MAX_PLAYERS = "20";
        OPS = "IndigoMrow";
        DIFFICULTY = "hard";
        MODE = "survival";
        TZ = "America/New_York";
        ICON = "data/server-icon.png";

        ONLINE_MODE = "false";
        ENFORCE_SECURE_PROFILE = "false"; # Required for Floodgate also fuck MICROSOFT

        ENABLE_AUTOPAUSE = "true";
        MAX_TICK_TIME = "-1";
        # How long to wait after the last player leaves before pausing
        AUTOPAUSE_TIMEOUT_EST = "172800"; # 2 days in seconds
        # server list message motd while sleeping
        AUTOPAUSE_KICK_MESSAGE = "Bnuyhole is sleeping. Please wait 60s for wake-up!";
        # prevents the server from pausing if there is a backup running
        AUTOPAUSE_RESERVED_ADR = "mc-backup";

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "/staging-plugins";
        # Plugins auto-download
        PLUGINS = "
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
	https://github.com/ViaVersion/ViaVersion/releases/download/5.8.1/ViaVersion-5.8.1.jar
	https://github.com/ViaVersion/ViaRewind/releases/download/4.0.15/ViaRewind-4.0.15.jar
	https://github.com/ViaVersion/ViaBackwards/releases/download/5.8.1/ViaBackwards-5.8.1.jar";
        INITIAL_COMMANDS = "gamerule keepInventory true";

        # RCON Setup
        # Internal only DO NOT expose in ports
        ENABLE_RCON = "true";
        JVM_OPTS = "--add-modules=jdk.incubator.vector -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:ZUncommitDelay=60";
      };
      volumes = [
        "/var/lib/minecraft/survival:/data"
        "/run/secrets/minecraft:/run/secrets/minecraft:ro"
        "/var/lib/minecraft/plugins/survival:/staging-plugins:ro"
      ];
    };
    containers.minecraft-lab = {
      image = "itzg/minecraft-server";
      # NO PORTS EXPOSED.
      environmentFiles = [ config.sops.secrets."minecraft_env".path ];
      extraOptions = [
        "--network=mc-net"
        "--add-host=host.docker.internal:host-gateway"
      ];
      environment = {
        EULA = "true";
        TYPE = "PAPER";
        VERSION = "1.21.11"; # wait this is cool
        INIT_MEMORY = "3G";
        MAX_MEMORY = "3G";
        MODE = "adventure";
        SIMULATION_DISTANCE = "6";
        VIEW_DISTANCE = "32";
        LEVEL_TYPE = "flat";
        GENERATOR_SETTINGS = "{\"layers\":[],\"biome\":\"minecraft:the_void\"}";
        INITIAL_COMMANDS = "gamerule keepInventory true";

        JVM_OPTS = "--add-modules=jdk.incubator.vector -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:ZUncommitDelay=60";

        ONLINE_MODE = "false";

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "/staging-plugins";
        PLUGINS = "
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
	https://github.com/ViaVersion/ViaVersion/releases/download/5.8.1/ViaVersion-5.8.1.jar
	https://github.com/ViaVersion/ViaRewind/releases/download/4.0.15/ViaRewind-4.0.15.jar
	https://github.com/ViaVersion/ViaBackwards/releases/download/5.8.1/ViaBackwards-5.8.1.jar";
        REMOVE_OLD_MODS = "true";
        REMOVE_OLD_MODS_DEPTH = "1";

        # Autopause
        ENABLE_AUTOPAUSE = "true";
        MAX_TICK_TIME = "-1";
        AUTOPAUSE_TIMEOUT_EST = "7200"; # 2 hours in seconds
        AUTOPAUSE_TIMEOUT_INIT = "7200";

        # server list message motd while sleeping
        AUTOPAUSE_KICK_MESSAGE = "Bnuyhole-lab is sleeping. Please wait 60s for wake-up!";
        # prevents the server from pausing if there is a backup running
        AUTOPAUSE_RESERVED_ADR = "mc-backup";

        ENABLE_RCON = "true";
      };
      volumes = [
        "/var/lib/minecraft/lab:/data"
        "/run/secrets/minecraft:/run/secrets/minecraft:ro"
        "/var/lib/minecraft/plugins/lab:/staging-plugins:ro"
      ];
    };

    containers.minecraft-creative = {
      image = "itzg/minecraft-server";
      # getting secrets to work is a bitch
      environmentFiles = [
        config.sops.secrets."minecraft_env".path
      ];

      # Attach to local docker network
      extraOptions = [
        "--network=mc-net" # internal connections
        "--add-host=host.docker.internal:host-gateway"
      ]; # Server Properties

      environment = {
        EULA = "true";
        TYPE = "PAPER";
        VERSION = "1.21.11";
        SEED = "5874101288974760850";
        #SERVER_IP = ""; # Bind to all interfaces inside the container
        INIT_MEMORY = "1G";
        MAX_MEMORY = "5G";
        SIMULATION_DISTANCE = "6";
        VIEW_DISTANCE = "32";
        MAX_PLAYERS = "6";
        DIFFICULTY = "easy";
        MODE = "creative";
        TZ = "America/New_York";

        ONLINE_MODE = "false";
        ENFORCE_SECURE_PROFILE = "false"; # Required for Floodgate also fuck MICROSOFT

        ENABLE_AUTOPAUSE = "true";
        MAX_TICK_TIME = "-1";
        # How long to wait after the last player leaves before pausing
        AUTOPAUSE_TIMEOUT_EST = "7200"; # 2 hours in seconds
        # server list message motd while sleeping
        AUTOPAUSE_KICK_MESSAGE = "The creative server is sleeping. Please wait about 30s for wake-up!";
        # prevents the server from pausing if there is a backup running
        AUTOPAUSE_RESERVED_ADR = "mc-backup";

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "/staging-plugins";
        SPIGET_RESOURCES = ""; # Spigot ID's
        # Plugins auto-download
        PLUGINS = "
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
	https://github.com/ViaVersion/ViaVersion/releases/download/5.8.1/ViaVersion-5.8.1.jar
	https://github.com/ViaVersion/ViaRewind/releases/download/4.0.15/ViaRewind-4.0.15.jar
	https://github.com/ViaVersion/ViaBackwards/releases/download/5.8.1/ViaBackwards-5.8.1.jar";
        INITIAL_COMMANDS = "gamerule keepInventory true";
        # RCON Setup
        # Internal only DO NOT expose in ports
        ENABLE_RCON = "true";
        JVM_OPTS = "--add-modules=jdk.incubator.vector -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:ZUncommitDelay=60";
      };
      volumes = [
        "/var/lib/minecraft/creative:/data"
        "/run/secrets/minecraft:/run/secrets/minecraft:ro"
        "/var/lib/minecraft/plugins/creative:/staging-plugins:ro"
      ];
    };

    containers.minecraft-raina = {
      image = "itzg/minecraft-server:java8";
      # getting secrets to work is a bitch
      environmentFiles = [
        config.sops.secrets."minecraft_env".path
      ];

      # Attach to local docker network
      extraOptions = [
        "--network=mc-net" # internal connections
        "--add-host=host.docker.internal:host-gateway"
      ]; # Server Properties

      environment = {
        EULA = "true";
        TYPE = "PAPER";
        VERSION = "1.13";
        #SERVER_IP = ""; # Bind to all interfaces inside the container
        INIT_MEMORY = "1G";
        MAX_MEMORY = "5G";
        SIMULATION_DISTANCE = "6";
        VIEW_DISTANCE = "32";
        MAX_PLAYERS = "6";
        DIFFICULTY = "easy";
        MODE = "creative";
        TZ = "America/New_York";

        ONLINE_MODE = "false";
        ENFORCE_SECURE_PROFILE = "false"; # Required for Floodgate also fuck MICROSOFT

        ENABLE_AUTOPAUSE = "true";
        MAX_TICK_TIME = "-1";
        # How long to wait after the last player leaves before pausing
        AUTOPAUSE_TIMEOUT_EST = "7200"; # 2 hours in seconds
        # server list message motd while sleeping
        AUTOPAUSE_KICK_MESSAGE = "My love, your server needs a few seconds to start up! Please wait a second beutifull";
        # prevents the server from pausing if there is a backup running
        AUTOPAUSE_RESERVED_ADR = "mc-backup";

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "/staging-plugins";
        SPIGET_RESOURCES = ""; # Spigot ID's
        # Plugins auto-download
        PLUGINS = "
	https://github.com/ViaVersion/ViaVersion/releases/download/5.8.1/ViaVersion-5.8.1.jar
	https://github.com/ViaVersion/ViaRewind/releases/download/4.0.15/ViaRewind-4.0.15.jar
	https://github.com/ViaVersion/ViaBackwards/releases/download/5.8.1/ViaBackwards-5.8.1.jar";
        INITIAL_COMMANDS = "gamerule keepInventory true";

        # RCON Setup
        # Internal only DO NOT expose in ports
        ENABLE_RCON = "true";
      };
      volumes = [
        "/var/lib/minecraft/raina:/data"
        "/run/secrets/minecraft:/run/secrets/minecraft:ro"
        "/var/lib/minecraft/plugins/raina:/staging-plugins:ro"
      ];
    };

    containers.mc-backup = {
      image = "itzg/mc-backup";
      # Local network for docker containers
      extraOptions = [
        "--network=mc-net"
        "--cpu-shares=256" # Cpu priority setting to 1/4th the rest of the system
      ]; # by setting the cpu priority lower, its less likely to lag, and its not time sensitive or too important so it can be lowered thusly

      environmentFiles = [
        config.sops.secrets."minecraft_env".path
      ];

      environment = {
        BACKUP_METHOD = "restic";
        RESTIC_REPOSITORY = "/backups";
        RESTIC_HOSTNAME = "Bnuyhole-Network";

        # Backup logic
        BACKUP_INTERVAL = "30m";
        PRUNE_RESTIC_RETENTION = "--keep-last 5 --keep-hourly 24 --keep-daily 12 --keep-weekly 4 --keep-monthly 3  --keep-yearly 2";
        PAUSE_IF_NO_PLAYERS = "false";

        # Terrible evil vile server player count checker that needs to be merged with itzg
        PRE_BACKUP_SCRIPT = ''
          	 echo "Checking network player count..."

          	 export MINECRAFT_SERVERS="${servers}"

          	 echo "[DEBUG] MINECRAFT_SERVERS=$MINECRAFT_SERVERS"

          	 TOTAL_PLAYERS=0

          	 for s in $MINECRAFT_SERVERS; do
          	   RAW=$(rcon-cli --host minecraft-$s list 2>/dev/null || echo "offline")

          	   CLEAN=$(echo "$RAW" | sed "s/$(printf '\033')\[[0-9;]*m//g")

          	   P=$(echo "$CLEAN" | sed -nE 's/.*There are[^0-9]*([0-9]+).*/\1/p' | head -n 1)
          	   if [[ ! "$P" =~ ^[0-9]+$ ]]; then
                	     P=0
              	   fi

          	   TOTAL_PLAYERS=$((TOTAL_PLAYERS + P))
          	 done

          	 echo "Total Network: $TOTAL_PLAYERS"

          	 if [ "$TOTAL_PLAYERS" -eq 0 ]; then
          	   echo "Zero players detected. Aborting backup."
          	   exit 1
          	 fi

          	 echo "Players found! Continuing backup..."
          	'';
        # RCON local terminal for sending commands and fetching data locally
        RCON_HOST = "minecraft-survival";
      };
      volumes = [
        "/var/lib/minecraft:/data:ro" # Read-only so backups can't break the world
        "/var/backups/minecraft:/backups"
      ];
      dependsOn = [
        "minecraft-survival"
        "minecraft-lab"
      ];
    };

  };

  systemd.services.remote-mc-backup = {
    description = "Rsync Minecraft Backups to Remote Storage";
    serviceConfig = {
      Type = "oneshot";
      User = "root";

      # LOW PRIORITY LOL
      Nice = 19;
      IOSchedulingClass = "idle";

      ExecStart = ''
        ${pkgs.rsync}/bin/rsync -avz --delete --partial --timeout=60 --bwlimit=5000 \
          -e "${pkgs.openssh}/bin/ssh -p 5432 -o StrictHostKeyChecking=accept-new" \
          /var/backups/minecraft/ \
          fur3@70.22.183.131:/var/backups/remote/
      '';
    };
  };

  services.mysql = {
    enable = true;
    package = pkgs.mysql84;

    ensureDatabases = [ "evenmorefish" ];
    ensureUsers = [
      {
        name = "fish_admin";
        ensurePermissions = {
          "evenmorefish.*" = "ALL PRIVILEGES";
        };
      }
    ];

    settings = {
      mysqld = {
        bind-address = "0.0.0.0";
      };
    };
  };

  # Creates the fish_admin@'172.21.0.%' MySQL user with the password from the SOPS secret
  # (the ensureUsers above only creates @localhost with unix_socket auth)
  systemd.services.mysql-create-fish-user = {
    description = "Create fish_admin MySQL user for Docker subnet";
    after = [ "mysql.service" "sops-nix.service" ];
    requires = [ "mysql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      ExecStart = "${pkgs.writeShellScript "mysql-create-fish-user" ''
        set -e
        PASSWORD=$(cat /run/secrets/minecraft/MYSQL_PASSWORD)
        ${pkgs.mysql84}/bin/mysql -u root -N <<-EOSQL
          CREATE USER IF NOT EXISTS 'fish_admin'@'172.21.0.%' IDENTIFIED BY '$PASSWORD';
          GRANT ALL PRIVILEGES ON evenmorefish.* TO 'fish_admin'@'172.21.0.%';
          FLUSH PRIVILEGES;
        EOSQL
      ''}";
    };
  };

  systemd.timers.remote-mc-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:00:00"; # 3AM
      Persistent = true; # the evil line
      RandomizedDelaySec = "10m"; # Add a slight random delay (up to 10m) so it doesn't fight with any scheduled jobs
    };
  };

  systemd.services.minecraft-secret-sanitizer = {
    description = "Clean Paper YAML duplicates and CRLF";
    before = [ "docker-minecraft-survival.service" ];
    after = [ "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # We wrap the script in ${ } to turn the derivation into a string path for ExecStart
      ExecStart = "${pkgs.writeShellScript "minecraft-sanitizer" ''
        # Set PATH so we don't have to use full paths for every command
        PATH="${pkgs.gnused}/bin:${pkgs.coreutils}/bin"
        FILE="/var/lib/minecraft/survival/config/paper-global.yml"

        if [ -f "$FILE" ]; then
          echo "Sanitizing $FILE..."
          # Use \x27 instead of to avoid Nix syntax errors.
          # This removes the exact line: secret: 
          sed -i "/secret: \x27\x27/d" "$FILE"
          # This removes any lines that end with 'secret: ' (and trailing whitespace)
          sed -i "/secret:[[:space:]]*$/d" "$FILE"
          # This removes Windows line endings (CRLF -> LF)
          sed -i "s/\r//g" "$FILE"
          echo "Sanitization complete."
        else
          echo "Warning: $FILE not found."
        fi
      ''}";
      RemainAfterExit = true;
    };
  };

  systemd.services.mc-watchdog = {
    description = "Minecraft Server Watchdog";

    # Add all required binaries to the service path
    path = [
      pkgs.docker
      pkgs.systemd
      pkgs.util-linux # wall
      pkgs.gnugrep # grep
      pkgs.coreutils # echo
    ];

    script = ''
            check_mc_server() {
              local container_name=$1
              local service_name="docker-$1"
              local port=$2

              echo "Checking $container_name..."
      	
      	# Checks if the docker container exists.
              if ! docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                echo "WATCHDOG: $container_name is STOPPED."
                wall "WATCHDOG: $container_name is STOPPED."
                #systemctl start "$service_name"
                return
              fi
            }

            check_mc_server "minecraft-survival" 25565
            check_mc_server "minecraft-lab" 25565
            check_mc_server "minecraft-creative" 25565
            #check_mc_server "minecraft-raina" 25565
            exit 0
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Watchdog timer that activates minecraft watchdog (above)
  systemd.timers.mc-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3m"; # Give the server 3 mins to start up before yelling
      OnUnitActiveSec = "1m"; # Run every 1 minute
    };
  };
  systemd.services."docker-minecraft-survival" = {
    serviceConfig = {
      Restart = pkgs.lib.mkForce "always";
      RestartSec = "5m"; # Wait 5 Minutes before trying to restart
      StartLimitIntervalSec = 0; # Disable restart rate limiting
    };
    preStart = ''

      mkdir -p /var/lib/minecraft/survival/config

      cp -f ${./paper-global.yml} /var/lib/minecraft/survival/config/paper-global.yml

      # Drop the bunny image into the root of the server data folder
      cp -f /etc/nixos/assets/server-icon.png /var/lib/minecraft/survival/server-icon.png


      mkdir -p /var/lib/minecraft/survival
      chown -R 1000:1000 /var/lib/minecraft/survival
      chmod -R u+rwX /var/lib/minecraft/survival
    '';
  };
  systemd.services."docker-minecraft-lab" = {
    serviceConfig = {
      Restart = pkgs.lib.mkForce "always";
      RestartSec = "5m"; # Wait 5 Minutes before trying to restart
      StartLimitIntervalSec = 0; # Disable restart rate limiting
    };
    preStart = ''

      mkdir -p /var/lib/minecraft/survival/config

      cp -f ${./paper-global.yml} /var/lib/minecraft/lab/config/paper-global.yml

      # Drop the bunny image into the root of the server data folder
      cp -f /etc/nixos/assets/server-icon.png /var/lib/minecraft/lab/server-icon.png


      mkdir -p /var/lib/minecraft/lab
      chown -R 1000:1000 /var/lib/minecraft/lab
      chmod -R u+rwX /var/lib/minecraft/lab
    '';
  };
  systemd.services."docker-minecraft-creative" = {
    serviceConfig = {
      Restart = pkgs.lib.mkForce "always";
      RestartSec = "5m"; # Wait 5 Minutes before trying to restart
      StartLimitIntervalSec = 0; # Disable restart rate limiting
    };
    preStart = ''

      mkdir -p /var/lib/minecraft/creative/config

      cp -f ${./paper-global.yml} /var/lib/minecraft/creative/config/paper-global.yml

      # Drop the bunny image into the root of the server data folder
      cp -f /etc/nixos/assets/server-icon.png /var/lib/minecraft/creative/server-icon.png


      mkdir -p /var/lib/minecraft/creative
      chown -R 1000:1000 /var/lib/minecraft/creative
      chmod -R u+rwX /var/lib/minecraft/creative
    '';
  };

  systemd.services."docker-minecraft-raina" = {
    serviceConfig = {
      Restart = pkgs.lib.mkForce "always";
      RestartSec = "5m"; # Wait 5 Minutes before trying to restart
      StartLimitIntervalSec = 0; # Disable restart rate limiting
    };
    preStart = ''

      mkdir -p /var/lib/minecraft/raina/config

      cp -f ${./paper-global.yml} /var/lib/minecraft/raina/config/paper-global.yml

      # Drop the bunny image into the root of the server data folder
      cp -f /etc/nixos/assets/server-icon.png /var/lib/minecraft/raina/server-icon.png


      mkdir -p /var/lib/minecraft/raina
      chown -R 1000:1000 /var/lib/minecraft/raina
      chmod -R u+rwX /var/lib/minecraft/raina
    '';
  };

  environment.systemPackages = with pkgs; [

    mysql84
    # This creates a sh in /run/current-system/sw/bin/bnuy-check
    (writeShellScriptBin "bnuy-check" ''
            case "$1" in
              snapshots) sudo docker exec mc-backup restic snapshots ;;
              check)     sudo docker exec mc-backup restic check ;;
              verify)    sudo docker exec mc-backup restic check --read-data ;;
              unlock)    sudo restic unlock -r /var/backups/minecraft/ --remove-all;;
              ls)        sudo docker exec mc-backup restic ls "''${2:-latest}" ;;
              
              stats)
                echo "Scanning Bnuyhole Repository..."
                export MINECRAFT_SERVERS="${servers}"
                JSON_SNAPS=$(sudo docker exec mc-backup restic snapshots --json)
                COUNT=$(echo "$JSON_SNAPS" | ${pkgs.jq}/bin/jq length)
                OLDEST=$(echo "$JSON_SNAPS" | ${pkgs.jq}/bin/jq -r '.[0].time[:16]' | tr 'T' ' ')
                NEWEST=$(echo "$JSON_SNAPS" | ${pkgs.jq}/bin/jq -r '.[-1].time[:16]' | tr 'T' ' ')

      	 #Previous implementation
                #LATEST_JSON=$(sudo docker exec mc-backup restic ls latest --json)
                #SURVIVAL_SIZE=$(echo "$LATEST_JSON" | ${pkgs.jq}/bin/jq -r 'select(.type=="file" and .path != null and (.path | contains("/survival/"))) | .size' | awk '{s+=$1} END {print s+0}')
                #LAB_SIZE=$(echo "$LATEST_JSON" | ${pkgs.jq}/bin/jq -r 'select(.type=="file" and .path != null and (.path | contains("/lab/"))) | .size' | awk '{s+=$1} END {print s+0}')
      	 
      	 LATEST_JSON=$(sudo docker exec mc-backup restic ls latest --json)

      	 declare_sizes=""

      	 for s in $MINECRAFT_SERVERS; do
      	   eval "$(echo "$LATEST_JSON" | ${pkgs.jq}/bin/jq -r \
      	     "select(.type==\"file\" and .path != null and (.path | contains(\"/$s/\"))) | .size" \
      	     | awk -v name="$s" '{sum+=$1} END {print name "_size=" sum+0}')"
      	 done
                RESTORE_SIZE=$(sudo docker exec mc-backup restic stats --mode restore-size --json | ${pkgs.jq}/bin/jq .total_size)
                RAW_SIZE=$(sudo docker exec mc-backup restic stats --mode raw-data --json | ${pkgs.jq}/bin/jq .total_size)
                SAVED=$((RESTORE_SIZE - RAW_SIZE))
                PERCENT_REDUCED=$(awk "BEGIN { printf \"%.2f\", (($RESTORE_SIZE - $RAW_SIZE) / $RESTORE_SIZE) * 100 }")
                RATIO=$(awk "BEGIN { if ($RAW_SIZE > 0) printf \"%.2f\", $RESTORE_SIZE / $RAW_SIZE; else print \"0.00\" }")

                to_gib() { echo | awk "{ printf \"%.2f GiB\", $1 / 1024 / 1024 / 1024 }"; }

                echo ""
                echo "========================================="
                echo "      BNUYHOLE NETWORK BACKUP STATS      "
                echo "========================================="
                echo " Snapshots          : $COUNT"
                echo " Range              : $OLDEST  ->  $NEWEST"
                echo "-----------------------------------------"
      	 for s in $MINECRAFT_SERVERS; do
      	   eval size=\$${s}_size
      	   printf " %-10s : %s\n" "$s" "$(to_gib "$size")"
      	 done     
      	 echo "-----------------------------------------"
                echo " Uncompressed Size  : $(to_gib $RESTORE_SIZE)"
                echo " Actual Size        : $(to_gib $RAW_SIZE)"
                echo " "
                echo " Compression Saved  : $(to_gib $SAVED) !"
                echo " Percentage smaller : $PERCENT_REDUCED%"
                echo " Compression ratio  : ''${RATIO}:1"
                echo "========================================="
                ;;
              *)
                echo "Usage: bnuy-check {snapshots|stats|ls|check|verify|unlock}"
                ;;
            esac
    '')

    #debating calling this rabbit-recover
    (writeShellScriptBin "bnuy-rollback" ''
      if [ "$EUID" -ne 0 ]; then echo "ERROR: Please run with sudo."; exit 1; fi

      # If somone cancels the rolback mid rolback, some nasty stuff used to happen, so i added this edge case.
      # im sure this is only a bandaid, but it works well in my shallow testing so ¯\_(ツ)_/¯      
      cleanup() {
        echo ""
        echo "Exiting... ensuring backup service is online." &
        systemctl start "docker-mc-backup"
        exit 1
      }

      trap cleanup SIGINT SIGTERM

      RESTIC_PASSWORD=$(grep '^RESTIC_PASSWORD=' "${
        config.sops.secrets."minecraft_env".path
      }" | cut -d '=' -f 2-)
      ACTION=$1

      perform_restore() {
        local SNAP_ID=$1
        local ACTION_NAME=$2
        local TARGET=$3

        local STATE_DIR="/var/lib/minecraft/.rollback/$TARGET"
        mkdir -p "$STATE_DIR"

        echo "Disabling backup service to prevent race conditions..."
        systemctl stop docker-mc-backup

        countdown 60 "[''${TARGET^^}] $ACTION_NAME starting in:" "Stopping in:" "true" "$TARGET"
        
        if [ "$TARGET" == "all" ]; then
          for s in minecraft-survival minecraft-lab minecraft-creative minecraft-raina; do
            echo "Disabling $s.."
            sudo docker stop "$s"
          done
        else
          sudo docker stop "minecraft-$TARGET" 
        fi

        if [ "$TARGET" == "all" ]; then
          for s in survival lab creative raina; do
            echo "Scrubbing $s live data to prevent Ghost Chunks..."
            rm -rf "/var/lib/minecraft/$s/world" "/var/lib/minecraft/$s/world_nether" "/var/lib/minecraft/$s/world_the_end"
          done
        else
          rm -rf "/var/lib/minecraft/$TARGET/world" "/var/lib/minecraft/$TARGET/world_nether" "/var/lib/minecraft/$TARGET/world_the_end"
        fi
        
        if [ "$TARGET" == "all" ]; then
          for s in survival lab creative raina; do
            echo "Restoring $s from snapshot: $SNAP_ID..."
            sudo docker run --rm \
              -v /var/lib/minecraft:/data \
              -v /var/backups/minecraft:/backups \
              -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
              restic/restic -r /backups restore "$SNAP_ID" --target / --include "/data/$s"         
          done
        else
          echo "Restoring $TARGET from snapshot: $SNAP_ID..."
          # We mount the root minecraft folder, and tell restic to only include the specific server's folder
          sudo docker run --rm \
            -v /var/lib/minecraft:/data \
            -v /var/backups/minecraft:/backups \
            -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
            restic/restic -r /backups restore "$SNAP_ID" --target / --include "/data/$TARGET"
        fi

        if [ "$TARGET" == "all" ]; then
          for s in survival lab creative raina; do
            echo "Restarting $s service..."

            systemctl reset-failed docker-mc-backup "docker-minecraft-$s"
            systemctl start "docker-minecraft-$s"
          done
        else
          systemctl reset-failed docker-mc-backup "docker-minecraft-$TARGET"
          systemctl start "docker-minecraft-$TARGET"
        fi

        systemctl start docker-mc-backup
        echo "$TARGET $ACTION_NAME Complete."

      }

      case "$ACTION" in
        list) sudo docker exec mc-backup restic snapshots ;; # I get this is a duplicate, sue me, its important functionality
        this)
          SNAP_ID=$2
          SERVER="''${3:-lab}"
          if [ -z "$SNAP_ID" ]; then echo "Provide Snapshot ID"; exit 1; fi
          
          STATE_DIR="/var/lib/minecraft/.rollback/$SERVER"
          mkdir -p "$STATE_DIR"
          
          echo "Creating pre-rollback safety snapshot for $SERVER..."
          sudo docker exec mc-backup backup now
          
          SAFETY_ID=$(sudo docker exec mc-backup restic snapshots --latest 1 --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
          echo "$SAFETY_ID" > "$STATE_DIR/last-safety-id"

          perform_restore "$SNAP_ID" "rollback" "$SERVER"
          ;;
        undo)
          SERVER="''${2:-lab}"
          STATE_DIR="/var/lib/minecraft/.rollback/$SERVER"
          if [ ! -f "$STATE_DIR/last-safety-id" ]; then echo "No undo history for $SERVER."; exit 1; fi
          RESTORE_SAFETY_ID="$(cat "$STATE_DIR/last-safety-id")"
          
          echo "Creating a pre-rollback last-safety-id so you can use  this command again, and it will functionally 'redo'"

          NEW_SAFETY_ID=$(sudo docker exec mc-backup restic snapshots --latest 1 --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
          echo "$NEW_SAFETY_ID" > "$STATE_DIR/last-safety-id"
          
          echo "restoring to the last rollback at the snapshot : $RESTORE_SAFETY_ID"
                    

          perform_restore "$RESTORE_SAFETY_ID" "rollback" "$SERVER"
          ;;
        *)
          echo "=== Bnuy-Rollback Help ==="
          echo "Usage: bnuy-rollback {list|this [snapshot_id] OR [server]|undo [server]}"
          echo ""
          echo "Parameters:"
          echo "  snapshot_id : Obtain via 'bnuy-rollback list'"
          echo "  server      : survival or lab (default: lab)"
          echo ""
          echo "Examples:"
          echo "  sudo bnuy-rollback list survival"
          echo "  sudo bnuy-rollback this 2a931bbd survival"
          echo "  sudo bnuy-rollback undo lab"
          ;;
      esac
    '')
    (writeShellScriptBin "countdown" ''
      #!/usr/bin/env bash
      if [ "$EUID" -ne 0 ]; then echo "ERROR: Run with sudo."; exit 1; fi

      total="''${1:-60}"

      InformServer="''${5:-all}"
      Statement="''${2:-Scheduled Server restart is in}"
      Countdown="''${3:-Restarting in}"

      # Command to run after the previous yelling 
      Command="''${4:-sudo systemctl restart docker-minecraft-survival.service}"

      # Gotta make sure its a actual command first
      FIRST_WORD=$(echo "$Command" | awk '{print $1}')
      if ! command -v "$FIRST_WORD" >/dev/null 2>&1; then echo "ERROR: Invalid command."; exit 1; fi
      echo "Countdown started for $total seconds..."

      # A smart way to only inform the servers that need to know of the rollback, potentially stemming fear if all servers heard a rollback was starting
      broadcast() {
        local msg="$1"
        if [ "$InformServer" == "all" ]; then
          for s in minecraft-survival minecraft-lab minecraft-creative minecraft-raina; do
            sudo docker exec "$s" rcon-cli say "$msg" >/dev/null 2>&1 || true
          done
        else
          sudo docker exec "minecraft-$InformServer" rcon-cli say "$msg" >/dev/null 2>&1 || true
        fi
      }

      for ((t = total; t > 0; t--)); do
        if ((t % 3600 == 0 && t != 0)); then
          string="''${Statement} $((t / 3600)) Hours(s)"
          broadcast "''${string}"
          echo "$string"
        elif ((t % 300 == 0 && t != 0)); then
          string="''${Statement} $((t / 60)) Minutes(s)"
          broadcast "''${string}"
          echo "$string"
        elif ((t == 60)); then
          string="''${Statement} $((t / 60)) Minutes(s)"
          broadcast "''${string}"
          echo "$string"
        elif ((t == 30)); then
          string="''${Statement} $t SECONDS"
          broadcast "''${string}"
          echo "$string"
        elif ((t == 15)); then
          string="''${Statement} $t SECONDS"
          broadcast "''${string}"
          echo "$string"
        elif ((t <= 10)); then
          string="''${Statement} $t"
          broadcast "''${string}"
          echo "$string"
        fi

        sleep 1
      done
      echo "executing the command '$4'"
      eval "$4"
    '')
  ];
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      25577
      25565
    ];
    allowedUDPPorts = [ 19132 ]; # Geyser
    extraCommands = ''
      # Allow the Docker bridge (usually docker0) to access MySQL
      iptables -A INPUT -i docker0 -p tcp --dport 3306 -j ACCEPT
      # Allow your custom 'mc-net' bridge (usually starts with br-) to access MySQL
      iptables -A INPUT -i br-+ -p tcp --dport 3306 -j ACCEPT
    '';

  };
  services.fail2ban = {
    enable = true;
    maxretry = 7;
    ignoreIP = [
      "127.0.0.1/8"
      "192.168.0.0/24"
    ]; # local network
  };
}
