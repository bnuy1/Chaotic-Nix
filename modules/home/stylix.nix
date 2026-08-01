{ config, lib, ... }:

{
  stylix.targets = {
    # Avoid fetching GNOME Shell sources on non-GNOME systems (breaks on some remotes)
    gnome.enable = false;

    # base16-stylix fish resets quickshell themes; let quickshell win
    fish.enable = false;

    # App theming is owned by quickshell's runtime Material You pipeline
    gtk.enable = false;
    qt.enable = false;
    kitty.enable = false;
    fuzzel.enable = false;
    foot.enable = false;
  };

  # quickshell renders its own wallpaper; keep the hyprpaper daemon out
  # (stylix's hyprland module forces services.hyprpaper.enable = true)
  services.hyprpaper.enable = lib.mkForce false;
}
