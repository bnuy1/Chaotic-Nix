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
    ./quest-hotspot.nix
    ../common-host-packages.nix
    ../../modules/hardware/antimatter.nix
  ];

  hardware.antimatter.enable = true;
  services.questHotspot.enable = true;
}
