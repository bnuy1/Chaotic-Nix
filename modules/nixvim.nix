{ pkgs, lib, ... }:
let
  nixvim = import (builtins.fetchGit {
    url = "https://github.com/nix-community/nixvim";
    # If you are not running an unstable channel of nixpkgs, select the corresponding branch of Nixvim.
    # ref = "nixos-25.11";
  });
in
{
  imports = [
    # For Home Manager
    #nixvim.homeModules.nixvim
    # For NixOS
    nixvim.nixosModules.nixvim
  ];

  programs.nixvim.enable = true;
}
