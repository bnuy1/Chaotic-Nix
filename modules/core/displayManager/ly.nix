{ pkgs, lib, config, ... }:
let
  dm = config.custom.displayManagerParsed;
in lib.mkIf (dm.name == "ly") {
  services.displayManager.ly.enable = true;
}
