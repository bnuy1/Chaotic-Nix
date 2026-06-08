{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.hardware.gpu.intel;
in
{
  options.hardware.gpu.intel = {
    enable = mkEnableOption "Intel GPU support" // { default = false; };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "modesetting" ];

    hardware.graphics.enable = true;
    hardware.graphics.extraPackages = with pkgs; [
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];

    boot.kernelModules = [ "kvm-intel" ];
  };
}
