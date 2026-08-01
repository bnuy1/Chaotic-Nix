{ pkgs, inputs, ... }:

{
  home.packages = [ pkgs.wlogout ];

  # style.css is generated at runtime by quickshell's apply-app-themes.sh
  xdg.configFile."wlogout/layout".source =
    "${inputs.dots-hyprland}/dots/.config/wlogout/layout";
}
