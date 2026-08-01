{ pkgs, lib, config, ... }:
let
  graphical = config.custom.displayManagerParsed.graphical;
in lib.mkIf graphical {
  programs.hyprland.enable = true;
  programs.uwsm.enable = true;
  services.hyprpolkitagent.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    # Enable FileChooser portal (needed by LibreWolf, GTK apps)
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };
}
