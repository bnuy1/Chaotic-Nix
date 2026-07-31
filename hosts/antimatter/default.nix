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
    ../common-host-packages.nix
    ../../modules/hardware/antimatter.nix
  ];

  hardware.antimatter.enable = true;
}
