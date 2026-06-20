{ ... }:
{
  stylix.targets = {
    # Avoid fetching GNOME Shell sources on non-GNOME systems (breaks on some remotes)
    gnome.enable = false;

    hyprland.enable = true;
    hyprlock.enable = false;
    ghostty.enable = false;
    qt = {
      enable = true;
      platform = "qtct";
    };
  };
}
