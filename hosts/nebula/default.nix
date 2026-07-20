{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
    ../common-host-packages.nix
    ../../modules/hardware/t440p.nix
  ];

  hardware.thinkpad-t440p.enable = true;
  hardware.thinkpad-t440p.gpu = "nvidia";
}
