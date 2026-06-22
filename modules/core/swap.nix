{ config, lib, vars, ... }:
let
  swp = vars.swap or {};
  hibernation = vars.hibernateEnable or false;
in {
  config = lib.mkIf (swp.enable or true) {
    zramSwap = {
      enable = true;
      memoryPercent = swp.zramPercent or 100;
      algorithm = swp.algorithm or "zstd";
    };

    swapDevices = lib.mkIf hibernation [
      { device = "/swapfile"; size = swp.swapFileSize or 8192; }
    ];
  };
}
