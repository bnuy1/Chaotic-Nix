{ inputs, lib, pkgs, ... }:
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
      treesitter.enable = true;
      notify.enable = true;
      noice.enable = true;
      gitsigns.enable = true;
      which-key.enable = true;
      comment.enable = true;
      luasnip.enable = true;
      friendly-snippets.enable = true;
      nvim-autopairs = {
        enable = true;
        settings = {
          check_ts = true;
          enable_check_bracket_line = false;
          fast_wrap = {
            enable = true;
            map = "<M-e>";
            chars = [ "{" "[" "(" "\"" "'" "`" ];
          };
        };
      };
      toggleterm = {
        enable = true;
        settings = {
          direction = "float";
        };
      };
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
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
          ts_ls.enable = true;
          html.enable = true;
          cssls.enable = true;
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
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
            javascriptreact = [ "prettierd" ];
            typescriptreact = [ "prettierd" ];
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
      colorizer.enable = true;
      treesitter-context.enable = false;
      project-nvim.enable = true;
      alpha = {
        enable = true;
        theme = "dashboard";
      };
      diffview.enable = true;
      hop.enable = true;
      leap.enable = true;
      vim-surround.enable = true;
      trouble.enable = true;
      markdown-preview.enable = true;
      lsp-signature.enable = true;
    };
    keymaps = [
      {
        key = "jk";
        mode = [ "i" ];
        action = "<ESC>";
        options.desc = "Exit insert mode";
      }
      {
        key = "<leader>ff";
        mode = [ "n" ];
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Search files by name";
      }
      {
        key = "<leader>lg";
        mode = [ "n" ];
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Search files by contents";
      }
      {
        key = "<leader>fe";
        mode = [ "n" ];
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "File browser toggle";
      }
      {
        key = "<leader>t";
        mode = [ "n" ];
        action = "<cmd>ToggleTerm<CR>";
        options.desc = "Toggle terminal";
      }
      {
        key = "<leader>.";
        mode = [ "n" ];
        action = "<cmd>lua require('Comment.api').toggle.linewise.current()<CR>";
        options.desc = "Comment line";
      }
      {
        key = "<leader>.";
        mode = [ "v" ];
        action = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>";
        options.desc = "Comment selection";
      }
      {
        key = "<leader>dj";
        mode = [ "n" ];
        action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
        options.desc = "Go to next diagnostic";
      }
      {
        key = "<leader>dk";
        mode = [ "n" ];
        action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
        options.desc = "Go to previous diagnostic";
      }
      {
        key = "<leader>dl";
        mode = [ "n" ];
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        options.desc = "Show diagnostic details";
      }
      {
        key = "<leader>dt";
        mode = [ "n" ];
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Toggle diagnostics list";
      }
      {
        key = "<F1>";
        mode = [ "n" "i" "v" "x" "s" "o" "t" "c" ];
        action = "<Nop>";
        options.desc = "Disable accidental F1 help";
      }
      {
        key = "<leader>h";
        mode = [ "n" ];
        action = ":help<Space>";
        options = { desc = "Open :help prompt"; nowait = true; };
      }
      {
        key = "<leader>H";
        mode = [ "n" ];
        action = ":help <C-r><C-w><CR>";
        options.desc = "Help for word under cursor";
      }
    ];
    extraPackages = with pkgs; [
      ripgrep
      fd
      bat
      wl-clipboard
      lazygit
      nil
      hyprls
      typescript-language-server
      typescript
      vscode-langservers-extracted
      pyright
      lua-language-server
      zls
      multimarkdown
      clang-tools
      prettierd
      stylua
      shfmt
      figlet
      toilet
    ];
    extraConfigLua = ''
      vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 2 },
        update_in_insert = true,
        severity_sort = true,
        underline = true,
        signs = true,
      })
      local ok, notify = pcall(require, 'notify')
      if ok then
        vim.notify = notify
      end
      do
        local ok_alpha, alpha = pcall(require, "alpha")
        if ok_alpha then
          local dashboard = require("alpha.themes.dashboard")
          local header_lines = nil
          local function gen_banner(cmd)
            local h = io.popen(cmd)
            if not h then return nil end
            local out = h:read("*a") or ""
            h:close()
            if #out == 0 then return nil end
            local lines = {}
            for line in out:gmatch("([^\n]*)\n?") do
              if line ~= "" then table.insert(lines, line) end
            end
            return #lines > 0 and lines or nil
          end
          header_lines = gen_banner('toilet -f ansi-shadow NIXVIM 2>/dev/null')
            or gen_banner('figlet -f "ANSI Shadow" NIXVIM 2>/dev/null')
            or gen_banner('figlet NIXVIM 2>/dev/null')
          if not header_lines then
            header_lines = {
              "███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗",
              "████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║",
              "██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║",
              "██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║",
              "██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║",
              "╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
            }
          end
          dashboard.section.header.val = header_lines
          dashboard.section.buttons.val = {
            dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
            dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
            dashboard.button("g", "󰺮  Live grep", ":Telescope live_grep<CR>"),
            dashboard.button("n", "  New file", ":enew<CR>"),
            dashboard.button("e", "  File browser", ":Neotree toggle<CR>"),
            dashboard.button("q", "  Quit", ":qa<CR>"),
          }
          local v = vim.version()
          dashboard.section.footer.val = string.format("NixVim • Neovim %d.%d.%d", v.major, v.minor, v.patch)
          dashboard.opts.opts.noautocmd = true
          alpha.setup(dashboard.config)
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "alpha",
            callback = function()
              vim.opt_local.foldenable = false
            end,
          })
        end
      end
    '';
  };
}
