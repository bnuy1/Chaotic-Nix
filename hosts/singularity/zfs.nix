{ config, lib, vars, ... }:

let
  zfsCfg = vars.zfs or {};
in
{
  boot.zfs.extraPools = [ "fast" "bulk" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  boot.zfs.forceImportRoot = false;

  systemd.services.zfs-mount.enable = false;
  services.zfs.autoScrub.enable = true;
}
