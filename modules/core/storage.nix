{ lib, vars, ... }:
let
  cfg = vars.btrfs or {};
in
lib.mkIf (cfg ? compress) {
  fileSystems = lib.mkDefault {
    "/" = {
      options = [ "compress=${cfg.compress}" ] ++ (cfg.mountOptions or [ "noatime" ]);
    };
  };
}
