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

      -- Material You theme: when running under Hyprland, rebuild highlight
      -- groups from the same MD3 palette the rest of the stack uses
      -- (~/.local/state/quickshell/user/generated/colors.json). Falls back to
      -- the configured colorscheme (catppuccin) everywhere else.
      do
        local function material_theme()
          local hypr = vim.env.HYPRLAND_INSTANCE_SIGNATURE
          if hypr == nil or hypr == "" then
            return false
          end
          local f = io.open(os.getenv("HOME") .. "/.local/state/quickshell/user/generated/colors.json", "r")
          if not f then
            return false
          end
          local raw = f:read("*a")
          f:close()
          local ok, c = pcall(vim.json.decode, raw)
          if not ok or type(c) ~= "table" or not c.background then
            return false
          end
          local bg = c.background
          local fg = c.onSurface or c.background
          local muted = c.onSurfaceVariant or fg
          local dim = c.outline or muted
          local container = c.surfaceContainer or bg
          local container_low = c.surfaceContainerLow or container
          local container_high = c.surfaceContainerHigh or container
          local container_highest = c.surfaceContainerHighest or container
          local primary = c.primary or fg
          local on_primary = c.onPrimary or bg
          local primary_container = c.primaryContainer or container
          local on_primary_container = c.onPrimaryContainer or fg
          local secondary = c.secondary or fg
          local secondary_container = c.secondaryContainer or container
          local on_secondary_container = c.onSecondaryContainer or fg
          local tertiary = c.tertiary or fg
          local error = c.error or c.term1 or fg
          local function hl(g, o) vim.api.nvim_set_hl(0, g, o) end
          local function set(groups, o) for _, g in ipairs(groups) do hl(g, o) end end
          hl("Normal", { fg = fg, bg = bg })
          hl("NormalFloat", { fg = fg, bg = container_low })
          set({ "FloatBorder", "FloatTitle", "FloatFooter" }, { fg = dim, bg = container_low })
          hl("EndOfBuffer", { fg = bg })
          hl("NonText", { fg = dim })
          hl("Whitespace", { fg = container_highest })
          hl("SpecialKey", { fg = tertiary })
          hl("Conceal", { fg = dim })
          set({ "LineNr", "LineNrAbove", "LineNrBelow" }, { fg = dim })
          hl("CursorLineNr", { fg = primary, bold = true })
          hl("CursorLine", { bg = container_low })
          hl("CursorColumn", { bg = container_low })
          hl("ColorColumn", { bg = container })
          set({ "Cursor", "iCursor", "lCursor" }, { bg = fg, fg = bg })
          set({ "SignColumn", "FoldColumn" }, { bg = bg, fg = dim })
          hl("Folded", { fg = muted, bg = container })
          hl("MatchParen", { fg = primary, bg = primary_container, bold = true })
          hl("Search", { fg = on_primary, bg = primary })
          hl("IncSearch", { fg = on_secondary_container, bg = secondary_container })
          hl("CurSearch", { fg = bg, bg = primary })
          hl("Substitute", { fg = on_primary, bg = primary })
          hl("QuickFixLine", { bg = container_high, fg = fg })
          hl("MsgArea", { fg = fg })
          hl("ModeMsg", { fg = primary, bold = true })
          hl("MoreMsg", { fg = primary })
          hl("Question", { fg = primary })
          hl("ErrorMsg", { fg = error, bold = true })
          hl("WarningMsg", { fg = secondary })
          hl("Error", { fg = error })
          hl("Todo", { fg = on_primary_container, bg = primary_container })
          hl("StatusLine", { fg = fg, bg = container_high })
          hl("StatusLineNC", { fg = dim, bg = container_low })
          set({ "StatusLineTerm", "StatusLineTermNC" }, { fg = fg, bg = container_high })
          set({ "TabLine" }, { fg = muted, bg = container })
          hl("TabLineSel", { fg = on_primary, bg = primary })
          hl("TabLineFill", { bg = container })
          hl("WinSeparator", { fg = dim, bg = bg })
          hl("VertSplit", { fg = container_highest, bg = bg })
          set({ "WinBar" }, { fg = fg, bg = container_low })
          set({ "WinBarNC" }, { fg = dim, bg = container_low })
          hl("Pmenu", { fg = fg, bg = container })
          hl("PmenuSel", { fg = on_primary_container, bg = primary_container })
          hl("PmenuKind", { fg = primary, bg = container })
          hl("PmenuKindSel", { fg = on_primary_container, bg = primary_container })
          hl("PmenuExtra", { fg = muted, bg = container })
          hl("PmenuExtraSel", { fg = on_primary_container, bg = primary_container })
          hl("PmenuMatch", { fg = primary, bg = container })
          hl("PmenuMatchSel", { fg = on_primary_container, bg = primary_container })
          hl("PmenuSbar", { bg = container_high })
          hl("PmenuThumb", { bg = primary_container })
          hl("PmenuBorder", { fg = dim })
          hl("Comment", { fg = muted, italic = true })
          hl("SpecialComment", { fg = muted, italic = true })
          hl("Constant", { fg = tertiary })
          hl("String", { fg = c.term10 or secondary })
          hl("Character", { fg = c.term12 or tertiary })
          hl("Number", { fg = c.term13 or tertiary })
          hl("Boolean", { fg = c.term13 or tertiary })
          hl("Float", { fg = c.term13 or tertiary })
          hl("Identifier", { fg = fg })
          hl("Function", { fg = c.term12 or tertiary })
          set({ "Statement", "Conditional", "Repeat", "Exception" }, { fg = secondary })
          hl("Keyword", { fg = primary })
          hl("Label", { fg = secondary })
          hl("Operator", { fg = fg })
          set({ "PreProc", "Include", "Define", "Macro", "PreCondit" }, { fg = c.term6 or secondary })
          set({ "Type", "StorageClass", "Structure", "Typedef" }, { fg = c.term12 or tertiary })
          hl("Special", { fg = c.term14 or secondary })
          hl("SpecialChar", { fg = c.term14 or secondary })
          hl("Tag", { fg = c.term5 or tertiary })
          hl("Delimiter", { fg = muted })
          hl("Debug", { fg = error })
          hl("Underlined", { underline = true, fg = primary })
          hl("DiagnosticError", { fg = error })
          hl("DiagnosticWarn", { fg = c.term11 or secondary })
          hl("DiagnosticInfo", { fg = primary })
          hl("DiagnosticHint", { fg = muted })
          hl("DiagnosticOk", { fg = c.term10 or primary })
          set({ "DiagnosticVirtualTextError", "DiagnosticSignError", "DiagnosticFloatingError" }, { fg = error })
          set({ "DiagnosticVirtualTextWarn", "DiagnosticSignWarn", "DiagnosticFloatingWarn" }, { fg = c.term11 or secondary })
          set({ "DiagnosticVirtualTextInfo", "DiagnosticSignInfo", "DiagnosticFloatingInfo" }, { fg = primary })
          set({ "DiagnosticVirtualTextHint", "DiagnosticSignHint", "DiagnosticFloatingHint" }, { fg = muted })
          set({ "DiagnosticVirtualTextOk", "DiagnosticSignOk", "DiagnosticFloatingOk" }, { fg = c.term10 or primary })
          hl("DiagnosticUnderlineError", { undercurl = true, sp = error })
          hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.term11 or secondary })
          hl("DiagnosticUnderlineInfo", { undercurl = true, sp = primary })
          hl("DiagnosticUnderlineHint", { undercurl = true, sp = muted })
          hl("DiagnosticUnderlineOk", { undercurl = true, sp = c.term10 or primary })
          set({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }, { bg = container_highest })
          hl("LspSignatureActiveParameter", { fg = on_secondary_container, bg = secondary_container, bold = true })
          hl("DiffAdd", { fg = c.term2 or primary, bg = container_low })
          hl("DiffChange", { fg = c.term11 or secondary, bg = container_low })
          hl("DiffDelete", { fg = error, bg = container_low })
          hl("DiffText", { fg = c.term3 or tertiary, bg = container_high })
          return true
        end
        material_theme()
        vim.api.nvim_create_autocmd("ColorScheme", {
          callback = function()
            material_theme()
          end,
        })
      end
    '';
  };
}
