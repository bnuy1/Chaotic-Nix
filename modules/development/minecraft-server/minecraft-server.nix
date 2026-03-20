{ pkgs, ... }:
{

  environment.shellAliases = {
    # Dumps logs to screen, then drops you into the RCON console indistinguishable from normal attaching sessions
    bnuy = "sudo docker logs minecraft && sudo docker exec -it minecraft rcon-cli";
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

    containers.minecraft = {
      image = "itzg/minecraft-server";
      ports = [
        "127.0.0.1:25565:25565/tcp"
        "25563:25563"
      ];
      # Attach to local docker network
      extraOptions = [
        "--network=mc-net" # internal connections
        "--log-opt"
        "max-size=50m" # bypass journald default sized logging
        "--log-driver=json-file" # although not required
      ]; # Server Properties

      environment = {
        EULA = "true";
        TYPE = "PAPER";
        VERSION = "1.21.11";
        SERVER_IP = ""; # Bind to all interfaces inside the container
        INIT_MEMORY = "8G";
        MAX_MEMORY = "8G";

        MOTD = "\u00a7l   \u00a7a                   Bnuyhole \u00a7c[1.21+]\u00a7r\n\u00a7l \u00a7d                Now with a \u00a7e\u00a7l\u00a7onew\u00a7d\u00a7n \u00a7obackend!";
        MAX_PLAYERS = "20";
        DIFFICULTY = "hard";
        MODE = "survival";
        ENFORCE_SECURE_PROFILE = "false"; # Required for Floodgate also fuck MICROSOFT

        OPS = "IndigoMrow,bnuydev";

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "./plugins";
        # Chest Shop
        SPIGET_RESOURCES = "81534"; # 51856"; # SpigotMC IDs  (cleaner and preferable)
        # Plugins auto-download
        #  citizens sentinel geyser floodgate
        PLUGINS = "
        https://ci.citizensnpcs.co/job/Denizen_Developmental/7267/artifact/target/Denizen-1.3.1-b7267-DEV.jar,
        https://github.com/EssentialsX/Essentials/releases/download/2.21.2/EssentialsX-2.21.2.jar,
        https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot,
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";

        REMOVE_OLD_MODS = "true";
        REMOVE_OLD_MODS_DEPTH = "1";
        # RCON Setup
        # Internal only DO NOT expose in ports
        ENABLE_RCON = "true";
        RCON_PASSWORD = "9xD7£2D/AWG+^2q";
      };
      volumes = [
        "/var/lib/minecraft:/data"
        "./plugins:/plugins-local:ro"
      ];
    };

    containers.mc-backup = {
      image = "itzg/mc-backup";
      # Local network for docker containers
      extraOptions = [
        "--network=mc-net"
        "--cpu-shares=256"
        "--log-opt" # Cpu priority setting to 1/4th the rest of the system
        "max-size=50m" # good practice not needed (on nixos)
        "--log-driver=json-file"
      ]; # by setting the cpu priority lower, its less likely to lag, and its not time sensitive or too important so it can be lowered thusly

      environment = {
        BACKUP_METHOD = "restic";
        RESTIC_REPOSITORY = "/backups";
        RESTIC_PASSWORD = "9xD7£2D/AWG+^2q"; # Encrypted backups anyone?
        RESTIC_HOSTNAME = "Bnuyhole";
        JVM_OPTS = "--add-modules=jdk.incubator.vector -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+UseNUMA -XX:+PerfDisableSharedMem -XX:ZUncommitDelay=60";

        # Backup logic
        BACKUP_INTERVAL = "1h";
        PRUNE_RESTIC_RETENTION = "--keep-last 5 --keep-hourly 24 --keep-daily 12 --keep-weekly 4 --keep-monthly 3  --keep-yearly 2";
        PAUSE_IF_NO_PLAYERS = "true";

        PRE_BACKUP_SCRIPT = ''
          echo "Server Backup Starting Now"
        '';
        # RCON local terminal for sending commands and fetching data locally
        RCON_HOST = "minecraft";
        RCON_PASSWORD = "9xD7£2D/AWG+^2q";
        # NOTE: unencrypted, and sends plaintext passwords soooooo mabye dont get hacked
      };
      volumes = [
        "/var/lib/minecraft:/data:ro" # Read-only so backups can't break the world
        "/var/backups/minecraft:/backups"
      ];
      dependsOn = [ "minecraft" ];
    };

  };

  /*
    systemd.services.remote-mc-backup = {
      description = "Rsync Minecraft Backups to Remote Storage";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.rsync}/bin/rsync -avz --delete /var/backups/minecraft/ user@ip:/backups/minecraft/";
      };
    };

    systemd.timers.remote-mc-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "03:00:00"; # Run daily at 3am
        Persistent = true;
      };
    };
  */

  systemd.services.mc-watchdog = {
    description = "Minecraft Server Watchdog";
    path = [
      pkgs.docker
      pkgs.util-linux
      #pkgs.libnotify # removed because it runs as root user, and thats in no way usefull
    ]; # docker wall and notify-send, respectfully
    script = ''
      # Check if the server responds to a ping using mc-monitor
      if ! docker exec minecraft mc-monitor status --host localhost --port 25565 >/dev/null 2>&1; then
        echo "WATCHDOG: Minecraft server is unreachable"
        
        # echo to all SSH terminals
        sudo wall "CRITICAL: Watchdog: Minecraft server is down or unresponsive"

        #notify-send -u critical "CRITICAL: Watchdog: Minecraft server is down or unresponsive"

      fi
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

  environment.systemPackages = with pkgs; [
    # This creates a sh in /run/current-system/sw/bin/bnuy-check
    (writeShellScriptBin "bnuy-check" ''
      case "$1" in
        snapshots) sudo docker exec mc-backup restic snapshots ;;
        stats)     sudo docker exec mc-backup restic stats ;;
        check)     sudo docker exec mc-backup restic check ;;
        verify)    sudo docker exec mc-backup restic check --read-data ;;
        ls)        sudo docker exec mc-backup restic ls "''${2:-latest}" ;;
        *) echo "Usage: bnuy-check {snapshots|stats|check|verify|ls [snapshot_id]}" ;;
      esac
    '')

    #debating calling this rabbit-recover
    (writeShellScriptBin "bnuy-rollback" ''
      # Store our state file for undo/redo logic
      STATE_FILE="/tmp/bnuy-rollback-state"
      TARGET_FILE="/tmp/bnuy-rollback-target"
      RESTIC_PASSWORD="9xD7£2D/AWG+^2q"

      # Arguments: $1 = Snapshot ID, $2 = Action Name (Rollback/Undo/Redo)
      perform_restore() {
        local SNAP_ID=$1
        local ACTION=$2

        sudo docker exec minecraft rcon-cli say "=== INITIATING SERVER ROLLBACK ==="
        echo "Starting $ACTION to snapshot: $SNAP_ID"
        
        countdown 60 "Server Rollback starting in :" "Rollback in :" "sudo systemctl stop docker-minecraft docker-mc-backup"

        echo "2. Restoring data..."
        sudo docker run --rm \
          -v /var/lib/minecraft:/data \
          -v /var/backups/minecraft:/backups \
          -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
          restic/restic -r /backups restore "$SNAP_ID" --target /

        echo "3. Cleaning up systemd and restarting..."
        sudo systemctl reset-failed docker-minecraft docker-mc-backup
        
        sudo systemctl start docker-mc-backup
        sleep 2
        sudo systemctl start docker-minecraft

        echo "$ACTION Complete."
      }



      case "$1" in
        list)
          if [ -n "$2" ] && [ -n "$3" ]; then
            echo "Showing recent snapshots..."
            sudo docker exec mc-backup restic snapshots --latest "$2"
          else
            sudo docker exec mc-backup restic snapshots
          fi
          ;;

      this)
        if [ -z "$2" ]; then
          echo "Error: Provide a snapshot ID (e.g., bnuy-rollback this 851eb7f0)"
          exit 1
        fi
        
        # Create safety backup
        echo "Creating safety pre-rollback backup..."
        sudo docker exec mc-backup backup now
        
        # Save IDs for future undo/redo
        SAFETY_ID=$(sudo docker exec mc-backup restic snapshots --latest 1 --json | grep -oP '"short_id":"\K[^"]+')
        echo "$SAFETY_ID" > "$STATE_FILE"
        echo "$2" > "$TARGET_FILE"

        # 3. Run the restore
        perform_restore "$2" "ROLLBACK"
        ;;

      undo)
        if [ ! -f "$STATE_FILE" ]; then
          echo "Error: No rollback history found."
          exit 1
        fi
        perform_restore "$(cat "$STATE_FILE")" "UNDO"
        ;;

      redo)
        if [ ! -f "$TARGET_FILE" ]; then
          echo "Error: No target history found."
          exit 1
        fi
        perform_restore "$(cat "$TARGET_FILE")" "REDO"
        ;;

        *)
          echo "Usage: bnuy-rollback {list [number] [hours/days]|this [snapshot_id]|undo|redo}"
          ;;
      esac
    '')
    (writeShellScriptBin "bnuy-check" ''
      case "$1" in
        snapshots) sudo docker exec mc-backup restic snapshots ;;
        stats)     sudo docker exec mc-backup restic stats ;;
        check)     sudo docker exec mc-backup restic check ;;
        verify)    sudo docker exec mc-backup restic check --read-data ;;
        ls)        sudo docker exec mc-backup restic ls "''${2:-latest}" ;;
        *) echo "Usage: bnuy-check {snapshots|stats|check|verify|ls [snapshot_id]}" ;;
      esac
    '')
    (writeShellScriptBin "countdown" ''
      #!/usr/bin/env bash

      total="''${1:-60}"

      Statement="''${2:-Scheduled Server restart is in}"
      Countdown="''${3:-Restarting in}"
      Command="''${4:-sudo systemctl restart docker-minecraft.service}"

      echo "Validating command..."
        # Extract the first word of the command
      FIRST_WORD=$(echo "$Command" | awk '{print $1}')
      if ! command -v "$FIRST_WORD" >/dev/null 2>&1; then
        echo "ERROR: Command '$FIRST_WORD' is not a valid executable."
        exit 1
      fi

      echo "Countdown started for $total seconds..."

      for ((t = total; t > 0; t--)); do
        if ((t % 3600 == 0 && t != 0)); then
          string="''${Statement} $((t / 3600)) Hours(s)"
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        elif ((t % 300 == 0 && t != 0)); then
          string="''${Statement} $((t / 60)) Minutes(s)"
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        elif ((t == 60)); then
          string="''${Statement} $((t / 60)) Minutes(s)"
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        elif ((t == 30)); then
          string="''${Statement} $t SECONDS"
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        elif ((t == 15)); then
          string="''${Statement} $t SECONDS"
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        elif ((t <= 10)); then
          string="''${Countdown} $t..."
          sudo docker exec minecraft rcon-cli say "$string"
          echo "$string"
        fi

        sleep 1
      done
      echo "executing the command '$4'"
      eval "$4"  ];
    '')
  ];
}
