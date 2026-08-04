# Single source of truth for every deviation we make against the end-4
# quickshell ii config shipped by `inputs.dots-hyprland`.
#
# The ii config has no native custom/ override layer (fonts, settings and
# most behaviors are hardcoded QML properties), so these patches stay. This
# manifest documents each one so end-4 input updates can be audited, and it
# generates `differences.md`:
#
#     nix eval --impure --expr '(import ./overrides.nix).markdown' --raw \
#       > differences.md
#
# `kind` is one of:
#   - replace  a whole file is replaced by a local copy (always re-deployed)
#   - patch    inline python/sed edit against upstream content (content-keyed)
#   - seed     upstream content is overwritten the first time, then preserved
#   - migrate  user config JSON value rewritten via jq (only shipped defaults)
#
# `keying` says how the override survives `nix flake lock --update-input
# dots-hyprland` rebuilds.
rec {
  pinnedInput = "dots-hyprland";
  pinnedRev = "aed4d1ec63f584905c28d2a678db5845579fdafc";
  overrides = [
    {
      id = "launch";
      kind = "replace";
      target = "~/.config/quickshell/launch.sh";
      upstream = "end-4 wrapper that relies on the repo env (gsettings schema XDG_DATA_DIRS, QS_ICON_THEME, venv activation).";
      ours = "NixOS wrapper: discovers gsettings schema dirs from the profile, sets QS_ICON_THEME=hicolor, activates the venv, then execs qs from /etc/profiles/per-user/$USER/bin/qs.";
      why = "end-4 launches qs via its own scripts that assume a repo checkout; on NixOS qs lives in a profile and gsettings schemas need XDG_DATA_DIRS.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "apply-app-themes";
      kind = "replace";
      target = "ii/scripts/colors/apply-app-themes.sh";
      upstream = "Writes fuzzel/gtk/foot/fish/wlogout themes from the MD3 palette.";
      ours = "Adds GTK3 legacy theme_* defines (adw-gtk3 dark, fixes GNOME MultiWriter), vesktop quickshell-m3.theme.css (Discord --brand-experiment etc.), spicetify quickshell-m3 color.ini + user.css.";
      why = "GTK3 fallback ignores modern libadwaita names; Electron/Vesktop/Spicetify have no native MD3 support so they read generated css vars.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "generate-colors-material";
      kind = "replace";
      target = "ii/scripts/colors/generate_colors_material.py";
      upstream = "Harmonizes terminal colors toward the primary hue (no-op at the forced harmony=0.05), so terminal never follows wallpaper/palette mode.";
      ours = "Rotates the six vivid ANSI hues with the scheme's primary hue; terminal follows wallpaper and dark/light mode.";
      why = "The terminal must reflect the active wallpaper, not a fixed palette.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "applycolor";
      kind = "replace";
      target = "ii/scripts/colors/applycolor.sh";
      upstream = "Runs only on full regeneration and breaks kitty reload.";
      ours = "Reads colors.json directly so it works on cached syncs too; applies kitty themes; additionally writes ~/.config/hypr/custom/colors.lua (active_border/inactive_border/background from MD3) and runs hyprctl reload so hypr borders follow the wallpaper.";
      why = "Hypr border/background colors must follow the MD3 palette (A5).";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "color-source-bridge";
      kind = "replace";
      target = "ii/services/ColorSourceBridge.qml";
      upstream = "end-4 palette source bridge.";
      ours = "Local copy wired for the Stylix palette source and wallpaper changes.";
      why = "Palette source (stylix) and runtime wallpaper sync.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "material-theme-loader";
      kind = "replace";
      target = "ii/services/MaterialThemeLoader.qml";
      upstream = "end-4 material theme loader.";
      ours = "Local copy that reads the SCSS-converted colors.json (camelCase keys) including the stylix fallback.";
      why = "colors.json layout differs from upstream expectations on NixOS.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "random-konachan";
      kind = "replace";
      target = "ii/scripts/colors/random/random_konachan_wall.sh";
      upstream = "Random wallpaper scripts fed empty files to switchwall and crashed the shell.";
      ours = "Hardened script with proper empty/error handling.";
      why = "Random wallpaper selection must be robust to API errors.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "switchwall-wrapper";
      kind = "replace";
      target = "ii/scripts/colors/switchwall.sh";
      upstream = "end-4 switchwall.sh (regenerates palette from wallpaper).";
      ours = "Wrapper: detects the stylix palette source (short-circuits to stylix-colors.json), injects --mode (gsettings is unavailable on NixOS and defaults to LIGHT otherwise), caches --noswitch syncs, converts material_colors.scss to colors.json for MaterialThemeLoader, forces terminal defaults, then delegates to the original.";
      why = "end-4 reads wallpaper mode/lightness via gsettings (missing on NixOS); the palette must be reproducible and cached.";
      keying = "Always overwritten at activation (rm + cp).";
    }
    {
      id = "quickconfig-osu";
      kind = "patch";
      target = "ii/modules/settings/QuickConfig.qml";
      upstream = "Ships a 'Random: osu! seasonal' button calling random_osu_wall.sh.";
      ours = "Button removed.";
      why = "osu.ppy.sh API v2 returns 403 without OAuth2; user chose to drop the feature rather than register a client.";
      keying = "Content-keyed: re-removed whenever random_osu_wall.sh is present.";
    }
    {
      id = "quickconfig-stylix";
      kind = "patch";
      target = "ii/modules/settings/QuickConfig.qml";
      upstream = "Palette option list ends at tonal-spot; onSelected passes only --noswitch.";
      ours = "Adds a 'Stylix' palette entry; onSelected passes --type <palette> --mode <dark|light> (mode preserved from m3colors).";
      why = "Stylix is the palette source on NixOS; end-4 dropped the mode flag which broke dark/light preservation.";
      keying = "Presence-keyed: added only when the stylix entry / --mode flag is missing.";
    }
    {
      id = "config-terminal-defaults";
      kind = "patch";
      target = "ii/modules/common/Config.qml";
      upstream = "property real harmony: 0.6 / harmonizeThreshold: 100 / termFgBoost: 0.35";
      ours = "harmony: 0.05 / harmonizeThreshold: 40 / termFgBoost: 0.05.";
      why = "Near-passthrough harmony keeps the vivid HCT hues' identity (red/blue must not wrap toward the wallpaper accent across the hue seam); minimal boost avoids washed-out fg.";
      keying = "Exact-string keyed: old values replaced when present.";
    }
    {
      id = "workspace-model-special";
      kind = "patch";
      target = "ii/modules/common/models/WorkspaceModel.qml";
      upstream = "specialWorkspaceActive: specialWorkspaceName !== '' (name is unreliable; hyprland always reports a specialWorkspace object).";
      ours = "Gates the special pill on specialWorkspace?.id !== 0 and blanks the fallback name.";
      why = "The pill showed even when no special workspace was open.";
      keying = "Content-keyed grep, re-applied on update.";
    }
    {
      id = "scheme-base";
      kind = "seed";
      target = "ii/scripts/colors/terminal/scheme-base.json";
      upstream = "Shipped Gruvbox scheme.";
      ours = "Vivid HCT-canonical base: six distinct hues (red 27 / green 145 / yellow 88 / blue 255 / magenta 330 / cyan 190), near-zero-chroma neutrals, near-white term7.";
      why = "With near-passthrough harmony these hues keep identity across wallpapers while --blend_bg_fg keeps bg/fg/term15 wallpaper-driven.";
      keying = "Marker-keyed: overwritten only while it still contains #CC241D (Gruvbox) or lacks our term1 marker, so user edits survive.";
    }
    {
      id = "kitty-template";
      kind = "patch";
      target = "ii/scripts/colors/terminal/kitty-theme.conf";
      upstream = "foreground/cursor set from $term7 (fixed grey).";
      ours = "foreground/cursor set from $onSurface (wallpaper surface, always present in material_colors.scss).";
      why = "Kitty fg/cursor should follow the wallpaper surface, not a static grey.";
      keying = "Content-keyed sed on the '$term7 #' template.";
    }
    {
      id = "switchwall-bak-matugen";
      kind = "patch";
      target = "ii/scripts/colors/switchwall.sh.bak";
      upstream = "Calls handle_kde_material_you_colors (matugen KDE wrapper, never installed) on every regen.";
      ours = "Call disabled.";
      why = "It errored every regeneration; enableQtApps=false already short-circuits it, this keeps it inert if Qt theming is re-enabled later.";
      keying = "Content-keyed sed, re-applied on update.";
    }
    {
      id = "switchwall-bak-applycolor";
      kind = "patch";
      target = "ii/scripts/colors/switchwall.sh.bak";
      upstream = "Reloads kitty and calls applycolor before the wrapper has rewritten colors.json.";
      ours = "Premature applycolor call dropped; wrapper reruns it after the JSON write.";
      why = "Kitty reloaded with stale colors on every wallpaper switch.";
      keying = "Content-keyed sed, re-applied on update.";
    }
    {
      id = "shapes";
      kind = "seed";
      target = "ii/modules/common/widgets/shapes";
      upstream = "Submodule (rounded-polygon) not populated in the nix input.";
      ours = "Copied from the rounded-polygon input.";
      why = "The shapes QML components are required by ii widgets.";
      keying = "Always copied at activation.";
    }
    {
      id = "config-json-terminal";
      kind = "migrate";
      target = "illogical-impulse/config.json (.appearance.wallpaperTheming.*)";
      upstream = "shipped defaults harmony 0.6/0.25, harmonizeThreshold 100/75, termFgBoost 0.35/0.15, enableQtApps true.";
      ours = "harmony=0.05, harmonizeThreshold=40, termFgBoost=0.05, enableQtApps=false.";
      why = "Match the near-passthrough terminal defaults; Qt theming bridges via GTK instead.";
      keying = "Only rewritten when the value still matches a shipped default, preserving user customizations.";
    }
    {
      id = "config-json-fullscreen";
      kind = "migrate";
      target = "illogical-impulse/config.json (.background.hideWhenFullscreen)";
      upstream = "default true.";
      ours = "false.";
      why = "hyprpaper is disabled here, so hiding the background layer would leave pure black behind fullscreen windows.";
      keying = "Only rewritten when true.";
    }
    {
      id = "venv";
      kind = "replace";
      target = "~/.local/state/quickshell/.venv";
      upstream = "end-4 expects a repo-local venv with materialyoucolor.";
      ours = "Bootstrap + repair on every activation: python3 venv, pip install materialyoucolor==2.0.10 pillow numpy opencv-python-headless (g++ on PATH), python.real symlink, LD_LIBRARY_PATH wrappers (libstdc++/libz) that do not leak globally.";
      why = "A system python upgrade breaks an existing venv; pip needs a compiler; global LD_LIBRARY_PATH breaks hyprctl.";
      keying = "Idempotent re-bootstrap every activation.";
    }
  ];

  markdown = let
    n = builtins.length overrides;
    clean = s: builtins.replaceStrings ["\n" "|" "`"] [" " "\\|" "'"] s;
    row = o: "| ${o.id} | ${o.kind} | \`${o.target}\` | ${clean o.why} |";
    imap0 = f: xs: builtins.genList (i: f i (builtins.elemAt xs i)) (builtins.length xs);
    detail = o: ''
      ### ${o.id}
      - Target: `${o.target}`
      - Kind: ${o.kind}
      - Upstream: ${o.upstream}
      - Ours: ${o.ours}
      - Why: ${o.why}
      - Survives updates: ${o.keying}
    '';
  in builtins.concatStringsSep "\n" ([
    "# Differences vs upstream end-4 (${pinnedInput})"
    ""
    "Generated from \`modules/home/quickshell/overrides.nix\` — do not edit by hand."
    ""
    "Pinned input: \`${pinnedInput}\` @ \`${pinnedRev}\`."
    "Update flow: \`nix flake lock --update-input ${pinnedInput}\` && rebuild."
    ""
    "## Override summary (${toString n})"
    ""
    "| id | kind | target | why |"
    "|---|---|---|---|"
  ] ++ (map row overrides) ++ [ "" "## Details" "" ] ++ imap0 (_: detail) overrides);
}
