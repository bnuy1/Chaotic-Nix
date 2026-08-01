{ lib, config, vars, ... }:
let
  dm = config.custom.displayManagerParsed;
  colors = config.lib.stylix.colors;
  wallpaperName =
    if lib.isDerivation config.stylix.image
    then config.stylix.image.name
    else builtins.baseNameOf config.stylix.image;
in {
  services.xserver.enable = dm.name == "sddm";
  services.displayManager.sddm.enable = dm.name == "sddm";

  programs.silentSDDM = lib.mkIf (dm.name == "sddm") {
    enable = true;
    theme = "default";
    backgrounds = {
      stylix = config.stylix.image;
    };
    settings = {
      "LoginScreen" = {
        background = wallpaperName;
        use-background-color = false;
      };
      "LockScreen" = {
        background = wallpaperName;
        use-background-color = false;
      };
      "LoginScreen.LoginArea.Avatar" = {
        active-border-color = colors.withHashtag.base0D;
        inactive-border-color = colors.withHashtag.base03;
      };
      "LoginScreen.LoginArea.Username" = {
        color = colors.withHashtag.base05;
      };
      "LoginScreen.LoginArea.PasswordInput" = {
        content-color = colors.withHashtag.base05;
        background-color = colors.withHashtag.base00;
        border-color = colors.withHashtag.base0D;
      };
      "LoginScreen.LoginArea.LoginButton" = {
        background-color = colors.withHashtag.base0D;
        content-color = colors.withHashtag.base00;
        border-color = colors.withHashtag.base0D;
        active-background-color = colors.withHashtag.base0C;
        active-content-color = colors.withHashtag.base00;
      };
      "LoginScreen.LoginArea.WarningMessage" = {
        normal-color = colors.withHashtag.base05;
        warning-color = colors.withHashtag.base09;
        error-color = colors.withHashtag.base08;
      };
      "LoginScreen.MenuArea.Popups" = {
        background-color = colors.withHashtag.base01;
        content-color = colors.withHashtag.base05;
        active-option-background-color = colors.withHashtag.base0D;
        active-content-color = colors.withHashtag.base00;
        border-color = colors.withHashtag.base0D;
      };
    };
  };

  services.displayManager.sddm.settings.Theme.Current = lib.mkIf (dm.name == "sddm") "silent";

  services.gnome.gnome-keyring.enable = lib.mkIf (dm.name == "sddm") true;
  security.pam.services.login.enableGnomeKeyring = lib.mkIf (dm.name == "sddm") true;
  security.pam.services.hyprland.enableGnomeKeyring = lib.mkIf (dm.name == "sddm") true;
  security.pam.services.sddm.enableGnomeKeyring = lib.mkIf (dm.name == "sddm") true;

  services.xserver.xkb = {
    layout = vars.keyboardLayout;
    variant = vars.keyboardVariant;
  };
}
