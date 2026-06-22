{ inputs, ... }:
{
  imports = [
    ./boot.nix
    ./system.nix
    ./networking.nix
    ./virtualisation.nix
    ./polkit.nix
    ./home_manager.nix
    ./stylix.nix
    ./hyprland
    ./gaming
    ./quickshell.nix
    ./printing.nix
    ./swap.nix
    ./power-management.nix
    ./displayManager
    ./xwaylandvideobridge
    ./storage.nix
    ./snapshots.nix
    ../../modules/hardware/gpu
  ];
}
