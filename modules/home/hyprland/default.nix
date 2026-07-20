{ vars, dm, config, ... }:

let
  palette = config.lib.stylix.colors;
in
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
    "hypr/hyprlock.conf".text = ''
      # Star it up: https://github.com/hyprwm/hyprlock

      background {
          monitor =
          path = $HOME/Pictures/wallpapers
          color = rgb(${palette.base00})
          blur_passes = 2
          blur_size = 6
          noise = 0.01
          contrast = 0.9
          brightness = 0.8
          vibrancy = 0.2
          vibrancy_darkness = 0.0
      }

      input-field {
          monitor =
          size = 300, 60
          outline_thickness = 3
          dots_size = 0.2
          dots_spacing = 0.35
          dots_center = true
          outer_color = rgb(${palette.base0D})
          inner_color = rgb(${palette.base01})
          font_color = rgb(${palette.base05})
          fade_on_empty = false
          placeholder_text = <i>Password...</i>
          hide_input = false
          position = 0, -80
          halign = center
          valign = center
      }
    '';
    "hypr/hypridle.conf".source = ./hypridle.conf;
    "hypr/keybinds.conf".source = ./keybinds.conf;
    "hypr/windowrules.conf".source = ./windowrules.conf;

    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
  };
}
