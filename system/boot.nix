{ config, pkgs, ... }:
{
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
