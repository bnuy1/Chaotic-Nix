{ vars, dm, ... }:

{
  imports = [
    ./xdg-desktop-portal.nix
  ];
  wayland.windowManager.hyprland = {
    enable = dm.graphical;
    xwayland.enable = true;
    configType = "hyprlang";

    extraConfig = ''
      source = ~/.config/hypr/hyprland.conf
    '';
  };

  xdg.configFile = {
    "hypr/hyprland.conf".source = ./hyprland.conf;
    "hypr/hyprsunset.conf".source = ./hyprsunset.conf;
    "hypr/hyprlock.conf".source = ./hyprlock.conf;
    "hypr/hypridle.conf".source = ./hypridle.conf;
    "hypr/keybinds.conf".source = ./keybinds.conf;
    "hypr/windowrules.conf".source = ./windowrules.conf;

    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
  };
}
