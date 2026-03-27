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
    ./hyprland.nix
    ./steam.nix
    ./quickshell.nix
    ./printing.nix
  ];
}
