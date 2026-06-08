{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.hardware.gpu.nvidia;

  nvidiaPkg =
    if cfg.package == "legacy_470" then config.boot.kernelPackages.nvidiaPackages.legacy_470
    else if cfg.package == "legacy_390" then config.boot.kernelPackages.nvidiaPackages.legacy_390
    else config.boot.kernelPackages.nvidiaPackages.stable;
in
{
  options.hardware.gpu.nvidia = {
    enable = mkEnableOption "NVIDIA GPU support" // { default = false; };

    busId = mkOption {
      type = types.str;
      default = "";
      description = "PCI bus ID (e.g. PCI:1:0:0)";
    };

    package = mkOption {
      type = types.enum [ "stable" "legacy_470" "legacy_390" ];
      default = "stable";
      description = "NVIDIA driver package version";
    };

    open = mkOption {
      type = types.bool;
      default = false;
      description = "Use open kernel module (Turing+ GPUs)";
    };

    prime = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable PRIME offload for hybrid GPU setups";
      };

      intelBusId = mkOption {
        type = types.str;
        default = "";
        description = "Intel iGPU PCI bus ID (e.g. PCI:0:2:0) for PRIME";
      };

      amdBusId = mkOption {
        type = types.str;
        default = "";
        description = "AMD GPU PCI bus ID for PRIME hybrid with NVIDIA";
      };
    };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics.enable = true;

    hardware.nvidia = mkMerge [
      {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = cfg.open;
        nvidiaSettings = true;
        package = nvidiaPkg;
      }
      (mkIf cfg.prime.enable {
        prime.offload.enable = true;
        prime.nvidiaBusId = cfg.busId;
      })
      (mkIf (cfg.prime.enable && cfg.prime.intelBusId != "") {
        prime.intelBusId = cfg.prime.intelBusId;
      })
      (mkIf (cfg.prime.enable && cfg.prime.amdBusId != "") {
        prime.amdgpuBusId = cfg.prime.amdBusId;
      })
    ];
  };
}
