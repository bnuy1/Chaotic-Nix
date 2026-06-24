{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.hardware.gpu.amd;
in
{
  options.hardware.gpu.amd = {
    enable = mkEnableOption "AMD GPU support" // { default = false; };
    rocm = mkEnableOption "ROCm support" // { default = false; };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware.graphics.enable = true;

    boot.initrd.kernelModules = [ "amdgpu" ];

    nixpkgs.config.rocmSupport = mkIf cfg.rocm true;
  };
}
