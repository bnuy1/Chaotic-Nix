{ ... }:

{
  # User-level portal preference: prioritize Hyprland, fallback to GTK
  xdg.portal = {
    enable = true;
    config.common.default = [ "hyprland" "gtk" ];
  };
}
