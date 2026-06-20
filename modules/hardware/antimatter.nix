{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.antimatter;
in
{
  options.hardware.antimatter = {
    enable = lib.mkEnableOption "Antimatter (main desktop) hardware support";
  };

  config = lib.mkIf cfg.enable {
    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    boot.kernelModules = [
      "ath12k"
      "iwlwifi"
      "kvm-intel"
      "usbnet"
      "rndis_host"
      "cdc_ether"
      "cdc_subset"
    ];
    boot.kernelParams = [ ];

    boot.initrd.availableKernelModules = [
      "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"
    ];
  };
}
