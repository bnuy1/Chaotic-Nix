{ lib, pkgs, config, ... }:
let
  cfg = config.hardware.gpu.intel;
  inherit (lib) mkEnableOption mkIf;
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
