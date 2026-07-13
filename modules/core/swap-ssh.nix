{ config, lib, pkgs, vars, ... }:

let
  cfg = vars.swap or {};

  # LUKS swap UUID read from flake-relative file
  luksSwapUuid = lib.removeSuffix "\n" (builtins.readFile ../../secrets/luks-swap-uuid);
  hasLuksSwap = luksSwapUuid != "";

  # Map name derived from the LUKS device mapper name
  mapperName = "swap";

  # Collect SSH public keys from all configured users
  allUsers = vars.users or [];
  sshKeys = lib.unique (lib.concatLists (map (u: u.sshKeys or []) allUsers));

  # Flake-relative path to persisted initrd SSH host key
  initrdHostKey = ../../secrets/initrd-ssh-ed25519-key;
in
{
  config = {
    # LUKS initrd device for swap (backing device UUID from secrets file)
    boot.initrd.luks.devices = lib.mkIf hasLuksSwap {
      ${mapperName} = {
        device = "/dev/disk/by-uuid/${luksSwapUuid}";
        allowDiscards = true;
      };
    };

    # Initrd SSH for remote LUKS unlock (only when SSH keys are configured)
    boot.initrd.network = lib.mkIf (sshKeys != []) {
      enable = true;
      ssh = {
        enable = true;
        port = cfg.sshPort or vars.sshPort or 2222;
        hostKeys = [ initrdHostKey ];
        authorizedKeys = sshKeys;
      };
    };

    # Persist initrd SSH host key across rebuilds
    system.activationScripts.initrd-ssh-keys = lib.mkIf (sshKeys != []) {
      deps = [ ];
      text = ''
        mkdir -p /etc/secrets
        cp ${initrdHostKey} /etc/secrets/initrd-ssh-ed25519-key
        chmod 0600 /etc/secrets/initrd-ssh-ed25519-key
      '';
    };

    # ZFS: safe default, suppresses deprecation warning
    boot.zfs.forceImportRoot = false;
  };
}
