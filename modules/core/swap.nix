{ config, lib, vars, ... }:
let
  hibernation = vars.hibernateEnable or false;
in
{
  config = {
    zramSwap = {
      enable = true;
      memoryPercent = 100;
      algorithm = "zstd";
    };

    swapDevices = lib.mkIf hibernation [
      { device = "/swapfile"; size = 8192; }
    ];
  };
}
