{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.thinkpad-t440p;
in
{
  imports = [ ./gpu ];

  options.hardware.thinkpad-t440p = {
    enable = lib.mkEnableOption "ThinkPad T440p hardware support";

    gpu = lib.mkOption {
      type = lib.types.enum [ "intel" "nvidia" ];
      default = "nvidia";
      description = ''
        GPU configuration for ThinkPad T440p.
        intel: Intel HD 4600 only (i915).
        nvidia: Intel + NVIDIA GT 730M Optimus with PRIME offload.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.gpu.intel.enable = true;

    hardware.gpu.nvidia = lib.mkIf (cfg.gpu == "nvidia") {
      enable = true;
      package = "legacy_470";
      busId = "PCI:1:0:0";
      prime = {
        enable = true;
        intelBusId = "PCI:0:2:0";
      };
    };

    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    boot.kernelModules = [
      "kvm-intel"
      "thinkpad_acpi"
      "iwlwifi"
      "e1000e"
      "snd-hda-intel"
    ];

    boot.initrd.availableKernelModules = [
      "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"
    ];

    boot.kernelParams = [ "acpi_backlight=vendor" "intel_iommu=on" "iommu.passthrough=0" ];

    boot.blacklistedKernelModules = [ "thunderbolt" ];

    services.hardware.bolt.enable = false;

    services.libinput.enable = true;
    services.libinput.touchpad = {
      naturalScrolling = true;
      disableWhileTyping = true;
      clickMethod = "clickfinger";
    };

    services.thermald.enable = true;
    powerManagement.cpuFreqGovernor = "powersave";
  };
}
