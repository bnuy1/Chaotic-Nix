{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    nixpkgs.source = inputs.nixpkgs;
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };
    opts = {
      number = true;
      relativenumber = false;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      wrap = false;
      swapfile = false;
      termguicolors = true;
      signcolumn = "yes";
      updatetime = 200;
      cursorline = true;
      spell = true;
      spelllang = [ "en" ];
      clipboard = "unnamedplus";
    };
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = false;
      };
    };
    plugins = {
      web-devicons.enable = true;
      lualine.enable = true;
      bufferline.enable = true;
      indent-blankline.enable = true;
      illuminate.enable = true;
      neo-tree.enable = true;
      telescope.enable = true;
      treesitter = {
        enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          c
          cpp
        ];
      };
      notify.enable = true;
      noice.enable = true;
      gitsigns.enable = true;
      which-key.enable = true;
      comment.enable = true;
      nvim-autopairs.enable = true;
      toggleterm.enable = true;
      blink-cmp = {
        enable = true;
        settings = {
          keymap = {
            preset = "default";
            "<CR>" = [ "accept" "fallback" ];
            "<Tab>" = [ "select_next" "fallback" ];
            "<S-Tab>" = [ "select_prev" "fallback" ];
          };
          appearance.nerd_font_variant = "mono";
          completion.documentation = {
            auto_show = true;
            auto_show_delay_ms = 500;
          };
          sources.default = [ "lsp" "path" "snippets" "buffer" ];
          snippets.preset = "luasnip";
          fuzzy.implementation = "prefer_rust_with_warning";
          signature.enabled = true;
        };
      };
      luasnip.enable = true;
      friendly-snippets.enable = true;
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
          ts_ls.enable = true;
          html.enable = true;
          cssls.enable = true;
          clangd = {
            enable = true;
            cmd = [
              "clangd"
              "--background-index"
              "--clang-tidy"
            ];
          };
        };
        keymaps = {
          silent = true;
          diagnostic = {
            "<leader>dl" = "open_float";
            "[d" = "goto_prev";
            "]d" = "goto_next";
          };
          lspBuf = {
            "K" = "hover";
            "gd" = "definition";
            "gD" = "declaration";
            "gi" = "implementation";
            "gr" = "references";
            "<leader>rn" = "rename";
            "<leader>ca" = "code_action";
          };
        };
      };
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            nix = [ "alejandra" ];
            lua = [ "stylua" ];
            c = [ "clang-format" ];
            cpp = [ "clang-format" ];
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
            css = [ "prettierd" ];
            html = [ "prettierd" ];
            markdown = [ "prettierd" ];
            sh = [ "shfmt" ];
          };
          format_on_save = {
            lsp_fallback = true;
          };
        };
      };
    };
    extraPackages = with pkgs; [
      ripgrep
      fd
      clang-tools
      nil
      typescript-language-server
      typescript
      vscode-langservers-extracted
      pyright
      lua-language-server
      prettierd
      stylua
      shfmt
    ];
    extraConfigLua = ''
      vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 2 },
        update_in_insert = true,
        severity_sort = true,
        underline = true,
        signs = true,
      })
    '';
  };
}
