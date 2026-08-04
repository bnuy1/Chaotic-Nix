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
    # hyprpolkitagent 0.1.3 always authenticates the first polkit identity
    # (identities.at(0)) instead of the session's user. With several wheel
    # members (admin, bnuy, raina) that makes it prompt for the wrong user's
    # password. Make the admin identity the subject's own user when they are
    # in wheel so the agent asks the correct user. Sorts before the generated
    # 10-nixos.rules, so this rule wins (polkit uses the first non-empty
    # admin rule).
    environment.etc."polkit-1/rules.d/00-session-admin.rules".text = ''
      polkit.addAdminRule(function(action, subject) {
        if (subject.isInGroup("wheel") && subject.user)
          return ["unix-user:" + subject.user];
        return ["unix-group:wheel"];
      });
    '';

    # gnome-multi-writer (and some other apps) hardcode /usr/bin/pkexec
    # instead of using PATH. Point it at NixOS's setuid wrapper.
    systemd.tmpfiles.rules = [
      "L+ /usr/bin/pkexec - - - - /run/wrappers/bin/pkexec"
    ];

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
