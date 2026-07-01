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
    ../../modules/server/netboot
  ];

  hardware.antimatter.enable = true;
  services.netboot = vars.netboot;
}
