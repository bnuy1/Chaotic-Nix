{ lib, vars, ... }:
let
  gpuDrivers = vars.gpuDrivers or [];
in
{
  imports = [
    ./intel.nix
    ./amd.nix
    ./nvidia.nix
  ];

  hardware.gpu.intel.enable = lib.elem "intel" gpuDrivers;
  hardware.gpu.amd.enable = lib.elem "amd" gpuDrivers;
  hardware.gpu.amd.rocm = lib.mkIf (vars.rocmEnable or null != null) vars.rocmEnable;
  hardware.gpu.nvidia = {
    enable = lib.elem "nvidia" gpuDrivers;
    powerManagement.enable = vars.nvidiaPowerManagement or false;
  };
}
