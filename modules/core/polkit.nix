{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  cfg = config.services.hyprpolkitagent;
in {

  options = {
    services.hyprpolkitagent = {
      enable = mkEnableOption "Hyprland Policykit Agent";
      package = mkPackageOption pkgs "hyprpolkitagent" { };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.hyprpolkitagent = {
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
