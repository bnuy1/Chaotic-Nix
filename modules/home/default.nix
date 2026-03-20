{ ... }:
let

in
{
  imports = [
    ./common-user-packages.nix
    ./kitty.nix
    ./hyprland
    ./stylix.nix
    ./noctalia.nix
    # Home Manager imports Nixvim uniquely
  ];
}
