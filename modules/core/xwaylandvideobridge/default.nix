{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dm = config.custom.displayManagerParsed;
in {
  options.programs.xwaylandvideobridge.enable = lib.mkOption {
    type = lib.types.bool;
    default = dm.graphical;
    description = "Enable xwaylandvideobridge for X11 screen sharing in Discord etc.";
  };

  config = lib.mkIf config.programs.xwaylandvideobridge.enable {
    environment.systemPackages = [
      inputs.xwaylandvideobridge.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
