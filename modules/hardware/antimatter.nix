{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.antimatter;
in
{
  imports = [ ./gpu ];

  options.hardware.antimatter = {
    enable = lib.mkEnableOption "Antimatter (main desktop) hardware support";
  };

  config = lib.mkIf cfg.enable {
    hardware.gpu.amd.enable = true;
    hardware.gpu.amd.rocm = true;

    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    boot.kernelModules = [ "ath12k_pci" "kvm-intel" ];

    boot.initrd.availableKernelModules = [
      "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"
    ];
  };
}
