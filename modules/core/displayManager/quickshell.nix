{ pkgs, lib, config, vars, ... }:
let
  dm = config.custom.displayManagerParsed;
  user = vars.autologinUser or null;
in
lib.mkIf (dm.name == "quickshell") (
  assert user != null;
  {
    # tty1 getty autologins once per boot into the Wayland session; other VTTs keep password logins
    services.xserver.enable = false;
    services.displayManager.sddm.enable = false;
    services.displayManager.ly.enable = false;

    # Boot to multi-user.target; uwsm starts the graphical session from the autologin shell
    systemd.defaultUnit = lib.mkForce "multi-user.target";

    # Keyboard layout on the console.
    console.keyMap = vars.consoleKeyMap or "us";

    # getty template (not a getty@tty1 instance) so the autovt alias still works
    services.getty.autologinUser = user;
    services.getty.autologinOnce = true;

    # gnome-keyring: no greeter PAM login, unlock happens at the lock screen
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.hyprland.enableGnomeKeyring = true;
  }
)
