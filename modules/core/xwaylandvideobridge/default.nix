{
  config,
  pkgs,
  lib,
  vars,
  inputs,
  ...
}:
{
  options.programs.xwaylandvideobridge.enable = lib.mkOption {
    type = lib.types.bool;
    default = vars.displayManager != null;
    description = "Enable xwaylandvideobridge for X11 screen sharing in Discord etc.";
  };

  config = lib.mkIf config.programs.xwaylandvideobridge.enable {
    environment.systemPackages = [
      inputs.xwaylandvideobridge.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
