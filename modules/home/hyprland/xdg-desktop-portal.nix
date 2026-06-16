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

  # Ensure the hyprland portal backend gets the right display
  systemd.user.services."xdg-desktop-portal-hyprland" = {
    Service = {
      Environment = "WAYLAND_DISPLAY=wayland-1";
    };
  };
}
