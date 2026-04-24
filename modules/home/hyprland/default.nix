{ ... }:

{
  imports = [
    ./xdg-desktop-portal.nix
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    # tells Home Manager to use the config file (that systemlinks everything together)
    extraConfig = ''
      source = ~/.config/hypr/hyprland.conf
    '';
  };

  # systemlinks all the files to ~/.config/hypr so it can use the nix store
  xdg.configFile = {
    "hypr/hyprland.conf".source = ./hyprland.conf;
    "hypr/hyprsunset.conf".source = ./hyprsunset.conf;
    "hypr/hypridle.conf".source = ./hypridle.conf;
    "hypr/keybinds.conf".source = ./keybinds.conf;
    "hypr/windowrules.conf".source = ./windowrules.conf;

    # The scripts directory and everything inside it >:3
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
  };
}
