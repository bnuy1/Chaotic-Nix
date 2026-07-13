{ ... }:

{
  #Hyprland GTK fallback
  xdg.portal = {
    enable = true;
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };
}
