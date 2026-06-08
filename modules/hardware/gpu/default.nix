{ lib, ... }:
{
  imports = [
    ./intel.nix
    ./amd.nix
    ./nvidia.nix
  ];
}
