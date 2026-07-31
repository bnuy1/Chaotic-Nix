{ ... }:
{
  stylix.targets = {
    # Avoid fetching GNOME Shell sources on non-GNOME systems (breaks on some remotes)
    gnome.enable = false;

    # base16-stylix fish emits OSC palette escapes that override quickshell's
    # generated kitty theme on every new shell. Let quickshell colors win.
    fish.enable = false;

    hyprland.enable = true;
    hyprlock.enable = false;
    ghostty.enable = false;
    qt = {
      enable = true;
      platform = "qtct";
    };
  };
}
