{ pkgs, vars, ... }:
let
  kernelOption = vars.kernel or "zen";
  kernelMap = {
    zen = pkgs.linuxPackages_zen;
    xanmod = pkgs.linuxPackages_xanmod;
    stable = pkgs.linuxPackages;
    lts = pkgs.linuxPackages_6_6;
  };
in
{
  boot.kernelPackages = kernelMap.${kernelOption};
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
