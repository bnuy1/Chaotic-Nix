{
  pkgs,
  lib,
  config,
  ...
}:
let
  graphical = config.custom.displayManagerParsed.graphical;
in
lib.mkIf graphical {
  environment.systemPackages = with pkgs; [
    waybar
    hypridle
    hyprlock
    awww
  ];
}
