{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.antimatter;
in
{
  options.hardware.antimatter = {
    enable = lib.mkEnableOption "Antimatter hardware support";
  };

  config = lib.mkIf cfg.enable {
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    boot.kernelModules = [
      "ath12k"
      "iwlwifi"
      "usbnet"
      "rndis_host"
      "cdc_ether"
      "cdc_subset"
      "snd-usb-audio"
    ];
    boot.kernelParams = [ ];

    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];

    # Disable WiFi power saving to prevent latency spikes for VR streaming.
    # iwlwifi: power_save=0 disables Intel WiFi power save.
    # ath12k: disable_ps=1 disables Qualcomm WiFi power save.
    boot.extraModprobeConfig = ''
      options iwlwifi swcrypto=1 power_save=0
      options ath12k disable_ps=1
    '';

    # Force WiFi adapters to stay powered on (prevent power_control auto-sleep).
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", ATTR{power/control}=="auto", ATTR{power/control}="on"
    '';
  };
}
