{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hardware.gpu.amd;
  inherit (lib) mkEnableOption mkIf;
in
{
  options.hardware.gpu.amd = {
    enable = mkEnableOption "AMD GPU support" // {
      default = false;
    };
    rocm = mkEnableOption "ROCm support" // {
      default = false;
    };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware.graphics.enable = true;
    boot.initrd.kernelModules = [ "amdgpu" ];
    services.lact.enable = true;
    hardware.amdgpu.overdrive.enable = true;
    nixpkgs.config.rocmSupport = mkIf cfg.rocm true;
  };
}
