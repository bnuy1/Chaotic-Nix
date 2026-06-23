{ pkgs, lib, config, vars, ... }:
let
  dm = config.custom.displayManagerParsed;
in {
  services.xserver.enable = dm.name == "sddm";
  services.displayManager.sddm.enable = dm.name == "sddm";

  services.gnome.gnome-keyring.enable = dm.name == "sddm";
  security.pam.services.hyprland.enableGnomeKeyring = dm.name == "sddm";
  security.pam.services.sddm.enableGnomeKeyring = dm.name == "sddm";

  services.xserver.xkb = {
    layout = vars.keyboardLayout;
    variant = vars.keyboardVariant;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkIf (dm.name == "sddm") "1";
}
