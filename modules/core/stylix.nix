{
  pkgs,
  vars,
  ...
}:

let
  # If quickshell has selected a wallpaper at runtime, use it for Stylix
  # The file is created by quickshell's ColorSourceBridge when a wallpaper is chosen
  runtimeWallpaper = ../assets/current-wallpaper.png;
  wallpaper = if builtins.pathExists runtimeWallpaper then runtimeWallpaper else vars.defaultBackgroundImage;
in
{
  # Styling Options
  stylix = {
    enable = true;
    image = wallpaper;

    polarity = vars.stylixPolarity or "dark";
    opacity.terminal = 1.0;

    # The base16-stylix fish theme emits OSC escape sequences that force the
    # terminal color palette to stylix colors on every new shell, overriding
    # quickshell's generated kitty theme. Disable it so quickshell colors win.
    targets.fish.enable = false;
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      sizes = {
        applications = 12;
        terminal = 15;
        desktop = 11;
        popups = 12;
      };
    };
  };
}
