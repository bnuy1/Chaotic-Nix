{ pkgs, ... }:
{
  # Zen kernal for bleeding edge speeeeed
  boot.kernelPackages = pkgs.linuxPackages_zen;
  # Unique to my system
  boot.kernelModules = [ "ath12k_pci" ];
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
    };
    grub = {
      efiSupport = true;
      #efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
      device = "nodev";
    };
  };

}
