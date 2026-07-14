{ config, lib, pkgs, vars, ... }:

let
  cfg = vars.swap or {};
  allUsers = vars.users or [];

  # LUKS swap UUID from host variables
  luksSwapUuid = cfg.luksSwapUuid or null;
  hasLuksSwap = luksSwapUuid != null && luksSwapUuid != "";
  hibernateEnabled = vars.hibernateEnable or false;

  # Collect SSH public keys from all configured users (for initrd authorized_keys)
  sshKeys = lib.unique (lib.concatLists (map (u: u.sshKeys or []) allUsers));

  # Find users who declared a remote LUKS decryption key (initrd SSH host key)
  hostKeyUsers = lib.filter (u: (u.remoteLuksDecryptionKeyPath or null) != null) allUsers;

  # Build paths and check existence
  hostKeyEntries = map (u:
    let home = u.homeDirectory or "/home/${u.name}";
    in {
      user = u.name;
      path = "${home}/.ssh/${u.remoteLuksDecryptionKeyPath}";
    }
  ) hostKeyUsers;

  existingEntries = lib.filter (e: builtins.pathExists e.path) hostKeyEntries;
  missingEntries = lib.filter (e: ! builtins.pathExists e.path) hostKeyEntries;

  existingKeys = map (e: e.path) existingEntries;

  hasAnyHostKeyDecl = hostKeyUsers != [];
  hasAnyExistingKey = existingKeys != [];
in
{
  config = {
    assertions = [
      {
        assertion = !(hasLuksSwap && hibernateEnabled);
        message = ''
          swap.luksSwapUuid and hibernateEnable cannot both be set.
          LUKS swap with a random key loses the key on reboot, making hibernation impossible.
        '';
      }
      {
        assertion = !(hasAnyHostKeyDecl && !hasAnyExistingKey && sshKeys != []);
        message = ''
          Initrd SSH authorized keys are configured but no remote LUKS decryption key was found.
          Declared paths:
          ${lib.concatStringsSep "\n" (map (e: "  ${e.path} (user: ${e.user})") hostKeyEntries)}

          Generate at least one with:
            ssh-keygen -t ed25519 -f <path> -N ""
        '';
      }
    ];

    warnings = map (e:
      "remoteLuksDecryptionKeyPath for user '${e.user}' points to ${e.path} which does not exist — key skipped"
    ) missingEntries;

    # LUKS initrd device for swap (UUID from host variables)
    boot.initrd.luks.devices = lib.mkIf hasLuksSwap {
      swap = {
        device = "/dev/disk/by-uuid/${luksSwapUuid}";
        allowDiscards = true;
      };
    };

    # Initrd SSH for remote LUKS unlock (requires both authorized keys and at least one host key)
    boot.initrd.network = lib.mkIf (sshKeys != [] && hasAnyExistingKey) {
      enable = true;
      ssh = {
        enable = true;
        port = cfg.sshPort or vars.sshPort or 2222;
        hostKeys = existingKeys;
        authorizedKeys = sshKeys;
      };
    };

    # ZFS: safe default, suppresses deprecation warning
    boot.zfs.forceImportRoot = false;
  };
}
