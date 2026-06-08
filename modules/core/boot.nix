{ pkgs, ... }:
{
  # Zen kernal for bleeding edge speeeeed
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      theme = ../../assets/grub-theme/breeze;
      efiSupport = true;
      device = "nodev";
    };
  };
  boot.tmp.cleanOnBoot = true;
}
