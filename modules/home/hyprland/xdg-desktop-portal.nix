{ pkgs, ... }:

{
  home.packages = with pkgs; [
    xdg-desktop-portal-hyprland
  ];

  xdg.portal = {
    enable = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];

    config.common.default = [ "hyprland" "gtk" ];
  };

  # Set WAYLAND_DISPLAY for the hyprland portal user service
  systemd.user.services."xdg-desktop-portal-hyprland".serviceConfig = {
    Environment = "WAYLAND_DISPLAY=wayland-0";
  };
}
