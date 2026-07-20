{ inputs, pkgs, ... }:
{
  imports = [
    ./base.nix
  ];

  programs.nixvim.plugins = {
    treesitter = {
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        c
        cpp
      ];
    };
    conform-nvim.settings.formatters_by_ft = {
      c = [ "clang-format" ];
      cpp = [ "clang-format" ];
    };
    lsp.servers.clangd = {
      enable = true;
      cmd = [
        "clangd"
        "--background-index"
        "--clang-tidy"
      ];
    };
  };
}
