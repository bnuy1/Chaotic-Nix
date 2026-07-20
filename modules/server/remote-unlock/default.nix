{ config, lib, ... }:

let
  cfg = config.services.remoteUnlock;
in
{
  options.services.remoteUnlock = {
    enable = lib.mkEnableOption "remote LUKS/ZFS unlock via initrd SSH";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "SSH port for initrd remote unlock";
    };

    hostKeys = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "SSH host key paths for initrd SSH server";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys allowed to connect during initrd";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hostKeys != [];
        message = "services.remoteUnlock.hostKeys must not be empty when enabled";
      }
      {
        assertion = cfg.authorizedKeys != [];
        message = "services.remoteUnlock.authorizedKeys must not be empty when enabled";
      }
    ];

    boot.initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = cfg.port;
        hostKeys = cfg.hostKeys;
        authorizedKeys = cfg.authorizedKeys;
      };
    };
  };
}
