{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  cfg = config.services.hyprpolkitagent;
  graphical = config.custom.displayManagerParsed.graphical;
in {

  options = {
    services.hyprpolkitagent = {
      enable = mkEnableOption "Hyprland Policykit Agent";
      package = mkPackageOption pkgs "hyprpolkitagent" { };
    };
  };

  config = {
    # Wheel may suspend/poweroff/reboot silently (session may be locked, no polkit prompt)
    security.polkit.extraConfig = lib.mkIf graphical ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          if (action.id == "org.freedesktop.login1.suspend" ||
              action.id == "org.freedesktop.login1.power-off" ||
              action.id == "org.freedesktop.login1.reboot") {
            return polkit.Result.YES;
          }
        }
      });
    '';

    systemd.user.services.hyprpolkitagent = lib.mkIf cfg.enable {
      description = "Hyprland PolicyKit Agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/libexec/hyprpolkitagent";
      };
    };
  };
}
