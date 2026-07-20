{ inputs, pkgs, ... }:
{
  imports = [
    ./base.nix
  ];

  programs.nixvim.plugins.lsp.servers.clangd.enable = true;
}
