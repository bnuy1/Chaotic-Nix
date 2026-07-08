{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    forceImportAll = false;
    forceImportRoot = false;
  };

  fileSystems."/" = {
    device = "rpool/local/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/local/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/safe/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/FAKE-SINGULARITY-BOOT";
    fsType = "vfat";
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
