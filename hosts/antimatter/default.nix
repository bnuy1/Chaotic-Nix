{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
    ../../modules/core/gaming/vr-hotspot
    ../common-host-packages.nix
    ../../modules/hardware/antimatter.nix
  ];

  hardware.antimatter.enable = true;
  services.questHotspot.enable = true;
}
