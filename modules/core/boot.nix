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
  # prevent /boot overflow
  boot.loader.grub.configurationLimit = vars.grubConfigLimit or 30;

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      theme = ../../assets/grub-theme/Sleek_Theme_Dark;
      efiSupport = true;
      device = "nodev";
    };
  };
  boot.tmp.cleanOnBoot = true;

  boot.kernelParams = [
    "slab_nomerge"                         # stops memory merge attacks
    "init_on_alloc=1"                      # clears memory before giving it out
    "init_on_free=1"                       # clears memory after its freed
    "tpm_tis.interrupts=0"                 # skip waiting for TPM interrupts
  ];
}
