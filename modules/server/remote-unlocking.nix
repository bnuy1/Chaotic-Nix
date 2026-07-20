{ config, lib, pkgs, vars, ... }:

let
  cfg = vars.initrdUnlock or {};
  enabled = cfg.enable or false;

  allUsers = vars.users or [];

  sshKeys = lib.unique (lib.concatLists (map (u: u.sshKeys or []) allUsers));

  hostKeyUsers = lib.filter (u: (u.remoteLuksDecryptionKeyPath or null) != null) allUsers;
  hostKeyPaths = map (u:
    let home = if (u.homeDirectory or null) != null then u.homeDirectory else "/home/${u.name}";
    in "${home}/.ssh/${u.remoteLuksDecryptionKeyPath}"
  ) hostKeyUsers;

  hasAnyHostKeyDecl = hostKeyPaths != [];
  networks = cfg.networks or {};
in
{
  config = lib.mkIf enabled {
    boot.initrd.network = lib.mkIf (sshKeys != [] && hasAnyHostKeyDecl) {
      enable = true;
      ssh = {
        enable = true;
        port = vars.sshPort or 2222;
        hostKeys = hostKeyPaths;
        authorizedKeys = sshKeys;
      };
    };

    boot.initrd.systemd.network = lib.mkIf (networks != {}) {
      enable = true;
      networks = networks;
    };
  };
}
