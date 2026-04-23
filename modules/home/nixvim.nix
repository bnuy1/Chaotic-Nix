{ pkgs, lib, ... }:
let
  nixvim = import (
    builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      # If you are not running an unstable channel of nixpkgs, select the corresponding branch of Nixvim.
      ref = "nixos-25.11";
    }
  );
in
{
  imports = [
    # For Home Manager
    nixvim.homeModules.nixvim
    # For NixOS
    #nixvim.nixosModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    # =========================
    # General Options
    # =========================
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      termguicolors = true;
      scrolloff = 8;
      updatetime = 300;
      signcolumn = "yes";
      wrap = false;
    };

    globals.mapleader = " ";

    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "mocha";
    };

    # =========================
    # Telescope
    # =========================
    plugins.telescope.enable = true;

    # =========================
    # Treesitter
    # =========================
    plugins.treesitter = {
      enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        rust
        python
        c
        cpp
        bash
        html
        css
        nix
        make
        bash
        json
        lua
        make
        markdown
        regex
        toml
        vim
        vimdoc
        xml
        yaml
      ];
    };

    # =========================
    # Git
    # =========================
    plugins.gitsigns.enable = true;
    plugins.fugitive.enable = true;

    # =========================
    # Completion
    # =========================
    plugins.cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        mapping = {
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping.select_next_item()";
          "<S-Tab>" = "cmp.mapping.select_prev_item()";
        };
      };
    };

    plugins.luasnip.enable = true;

    # =========================
    # LSP
    # =========================
    plugins.lsp = {
      enable = true;

      servers = {
        rust_analyzer = {
          enable = true;
          installCargo = true;
          installRustc = true;
        };
        pyright.enable = true;

        clangd = {
          enable = true;
          cmd = [
            "clangd"
            "--background-index"
          ];
        };

        bashls.enable = true;

        html.enable = true;
        cssls.enable = true;

        nil_ls.enable = true; # Nix LSP
        # Hyprland config support (uses bash LSP fallback)
      };
    };

    # =========================
    # Formatting / Linting
    # =========================
    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          rust = [ "rustfmt" ];
          python = [ "black" ];
          c = [ "clang-format" ];
          cpp = [ "clang-format" ];
          nix = [ "alejandra" ];
          sh = [ "shfmt" ];
          html = [ "prettier" ];
          css = [ "prettier" ];
        };
      };
    };

    plugins.lint = {
      enable = true;
      lintersByFt = {
        python = [ "ruff" ];
        nix = [ "statix" ];
        sh = [ "shellcheck" ];
      };
    };

    # =========================
    # UI Enhancements
    # =========================
    plugins.lualine.enable = true;
    plugins.which-key.enable = true;
    plugins.comment.enable = true;
    plugins.indent-blankline.enable = true;

    plugins.web-devicons.enable = true;

  };
}
