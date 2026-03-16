{ virtualisation }:
{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.minecraft = {
      image = "itzg/minecraft-server";
      ports = [
        "25565:25565/tcp" # Java Edition
        "19132:19132/udp" # Geyser/Bedrock Edition
      ];
      environment = {
        EULA = "true";
        TYPE = "PAPER";
        VERSION = "1.21.11";

        # Server Properties
        MOTD = "BnuyMC";
        MAX_PLAYERS = "20";
        DIFFICULTY = "hard";
        MODE = "survival";
        ENFORCE_SECURE_PROFILE = "false"; # Required for Floodgate also fuck MICROSOFT

        # Plugins SPIGOT auto download , but not all plugins support it)
        COPY_PLUGINS_SRC = "./plugins";

        SPIGET_RESOURCES = ""; # SpigotMC IDs  (cleaner and preferable)
        # Plugins auto-download
        PLUGINS = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot,https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";

        REMOVE_OLD_MODS = "true";
        REMOVE_OLD_MODS_DEPTH = "1";
        # RCON Setup
        # Internal only DO NOT expose in ports
        ENABLE_RCON = "true";
        RCON_PASSWORD = "change_this_to_a_secure_password";
      };
      volumes = [
        "/var/lib/minecraft:/data"
        "./plugins:/plugins-local:ro"
      ];
    };

    containers.mc-backup = {
      image = "itzg/mc-backup";
      environment = {
        # Backup logic
        BACKUP_INTERVAL = "1h";
        PRUNE_BACKUPS_DAYS = "14";
        PAUSE_IF_NO_PLAYERS = "true";

        # RCON local terminal for sending commands and fetching data locally
        RCON_HOST = "minecraft";
        RCON_PASSWORD = "W=+d7Ui75F&h?[L5#Hdes9";
        # NOTE: unencrypted, and sends plaintext passwords soooooo mabye dont get hacked
      };
      volumes = [
        "/var/lib/minecraft:/data:ro" # Read-only so backups can't break the world
        "/var/backups/minecraft:/backups"
      ];
      dependsOn = [ "minecraft" ];
    };
  };
}
