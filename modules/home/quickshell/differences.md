# Differences vs upstream end-4 (dots-hyprland)

Generated from `modules/home/quickshell/overrides.nix` — do not edit by hand.

Pinned input: `dots-hyprland` @ `aed4d1ec63f584905c28d2a678db5845579fdafc`.
Update flow: `nix flake lock --update-input dots-hyprland` && rebuild.

## Override summary (20)

| id | kind | target | why |
|---|---|---|---|
| launch | replace | `~/.config/quickshell/launch.sh` | end-4 launches qs via its own scripts that assume a repo checkout; on NixOS qs lives in a profile and gsettings schemas need XDG_DATA_DIRS. |
| apply-app-themes | replace | `ii/scripts/colors/apply-app-themes.sh` | GTK3 fallback ignores modern libadwaita names; Electron/Vesktop/Spicetify have no native MD3 support so they read generated css vars. |
| generate-colors-material | replace | `ii/scripts/colors/generate_colors_material.py` | The terminal must reflect the active wallpaper, not a fixed palette. |
| applycolor | replace | `ii/scripts/colors/applycolor.sh` | Hypr border/background colors must follow the MD3 palette (A5). |
| color-source-bridge | replace | `ii/services/ColorSourceBridge.qml` | Palette source (stylix) and runtime wallpaper sync. |
| material-theme-loader | replace | `ii/services/MaterialThemeLoader.qml` | colors.json layout differs from upstream expectations on NixOS. |
| random-konachan | replace | `ii/scripts/colors/random/random_konachan_wall.sh` | Random wallpaper selection must be robust to API errors. |
| switchwall-wrapper | replace | `ii/scripts/colors/switchwall.sh` | end-4 reads wallpaper mode/lightness via gsettings (missing on NixOS); the palette must be reproducible and cached. |
| quickconfig-osu | patch | `ii/modules/settings/QuickConfig.qml` | osu.ppy.sh API v2 returns 403 without OAuth2; user chose to drop the feature rather than register a client. |
| quickconfig-stylix | patch | `ii/modules/settings/QuickConfig.qml` | Stylix is the palette source on NixOS; end-4 dropped the mode flag which broke dark/light preservation. |
| config-terminal-defaults | patch | `ii/modules/common/Config.qml` | Near-passthrough harmony keeps the vivid HCT hues' identity (red/blue must not wrap toward the wallpaper accent across the hue seam); minimal boost avoids washed-out fg. |
| workspace-model-special | patch | `ii/modules/common/models/WorkspaceModel.qml` | The pill showed even when no special workspace was open. |
| scheme-base | seed | `ii/scripts/colors/terminal/scheme-base.json` | With near-passthrough harmony these hues keep identity across wallpapers while --blend_bg_fg keeps bg/fg/term15 wallpaper-driven. |
| kitty-template | patch | `ii/scripts/colors/terminal/kitty-theme.conf` | Kitty fg/cursor should follow the wallpaper surface, not a static grey. |
| switchwall-bak-matugen | patch | `ii/scripts/colors/switchwall.sh.bak` | It errored every regeneration; enableQtApps=false already short-circuits it, this keeps it inert if Qt theming is re-enabled later. |
| switchwall-bak-applycolor | patch | `ii/scripts/colors/switchwall.sh.bak` | Kitty reloaded with stale colors on every wallpaper switch. |
| shapes | seed | `ii/modules/common/widgets/shapes` | The shapes QML components are required by ii widgets. |
| config-json-terminal | migrate | `illogical-impulse/config.json (.appearance.wallpaperTheming.*)` | Match the near-passthrough terminal defaults; Qt theming bridges via GTK instead. |
| config-json-fullscreen | migrate | `illogical-impulse/config.json (.background.hideWhenFullscreen)` | hyprpaper is disabled here, so hiding the background layer would leave pure black behind fullscreen windows. |
| venv | replace | `~/.local/state/quickshell/.venv` | A system python upgrade breaks an existing venv; pip needs a compiler; global LD_LIBRARY_PATH breaks hyprctl. |

## Details

### launch
- Target: `~/.config/quickshell/launch.sh`
- Kind: replace
- Upstream: end-4 wrapper that relies on the repo env (gsettings schema XDG_DATA_DIRS, QS_ICON_THEME, venv activation).
- Ours: NixOS wrapper: discovers gsettings schema dirs from the profile, sets QS_ICON_THEME=hicolor, activates the venv, then execs qs from /etc/profiles/per-user/$USER/bin/qs.
- Why: end-4 launches qs via its own scripts that assume a repo checkout; on NixOS qs lives in a profile and gsettings schemas need XDG_DATA_DIRS.
- Survives updates: Always overwritten at activation (rm + cp).

### apply-app-themes
- Target: `ii/scripts/colors/apply-app-themes.sh`
- Kind: replace
- Upstream: Writes fuzzel/gtk/foot/fish/wlogout themes from the MD3 palette.
- Ours: Adds GTK3 legacy theme_* defines (adw-gtk3 dark, fixes GNOME MultiWriter), vesktop quickshell-m3.theme.css (Discord --brand-experiment etc.), spicetify quickshell-m3 color.ini + user.css.
- Why: GTK3 fallback ignores modern libadwaita names; Electron/Vesktop/Spicetify have no native MD3 support so they read generated css vars.
- Survives updates: Always overwritten at activation (rm + cp).

### generate-colors-material
- Target: `ii/scripts/colors/generate_colors_material.py`
- Kind: replace
- Upstream: Harmonizes terminal colors toward the primary hue (no-op at the forced harmony=0.05), so terminal never follows wallpaper/palette mode.
- Ours: Rotates the six vivid ANSI hues with the scheme's primary hue; terminal follows wallpaper and dark/light mode.
- Why: The terminal must reflect the active wallpaper, not a fixed palette.
- Survives updates: Always overwritten at activation (rm + cp).

### applycolor
- Target: `ii/scripts/colors/applycolor.sh`
- Kind: replace
- Upstream: Runs only on full regeneration and breaks kitty reload.
- Ours: Reads colors.json directly so it works on cached syncs too; applies kitty themes; additionally writes ~/.config/hypr/custom/colors.lua (active_border/inactive_border/background from MD3) and runs hyprctl reload so hypr borders follow the wallpaper.
- Why: Hypr border/background colors must follow the MD3 palette (A5).
- Survives updates: Always overwritten at activation (rm + cp).

### color-source-bridge
- Target: `ii/services/ColorSourceBridge.qml`
- Kind: replace
- Upstream: end-4 palette source bridge.
- Ours: Local copy wired for the Stylix palette source and wallpaper changes.
- Why: Palette source (stylix) and runtime wallpaper sync.
- Survives updates: Always overwritten at activation (rm + cp).

### material-theme-loader
- Target: `ii/services/MaterialThemeLoader.qml`
- Kind: replace
- Upstream: end-4 material theme loader.
- Ours: Local copy that reads the SCSS-converted colors.json (camelCase keys) including the stylix fallback.
- Why: colors.json layout differs from upstream expectations on NixOS.
- Survives updates: Always overwritten at activation (rm + cp).

### random-konachan
- Target: `ii/scripts/colors/random/random_konachan_wall.sh`
- Kind: replace
- Upstream: Random wallpaper scripts fed empty files to switchwall and crashed the shell.
- Ours: Hardened script with proper empty/error handling.
- Why: Random wallpaper selection must be robust to API errors.
- Survives updates: Always overwritten at activation (rm + cp).

### switchwall-wrapper
- Target: `ii/scripts/colors/switchwall.sh`
- Kind: replace
- Upstream: end-4 switchwall.sh (regenerates palette from wallpaper).
- Ours: Wrapper: detects the stylix palette source (short-circuits to stylix-colors.json), injects --mode (gsettings is unavailable on NixOS and defaults to LIGHT otherwise), caches --noswitch syncs, converts material_colors.scss to colors.json for MaterialThemeLoader, forces terminal defaults, then delegates to the original.
- Why: end-4 reads wallpaper mode/lightness via gsettings (missing on NixOS); the palette must be reproducible and cached.
- Survives updates: Always overwritten at activation (rm + cp).

### quickconfig-osu
- Target: `ii/modules/settings/QuickConfig.qml`
- Kind: patch
- Upstream: Ships a 'Random: osu! seasonal' button calling random_osu_wall.sh.
- Ours: Button removed.
- Why: osu.ppy.sh API v2 returns 403 without OAuth2; user chose to drop the feature rather than register a client.
- Survives updates: Content-keyed: re-removed whenever random_osu_wall.sh is present.

### quickconfig-stylix
- Target: `ii/modules/settings/QuickConfig.qml`
- Kind: patch
- Upstream: Palette option list ends at tonal-spot; onSelected passes only --noswitch.
- Ours: Adds a 'Stylix' palette entry; onSelected passes --type <palette> --mode <dark|light> (mode preserved from m3colors).
- Why: Stylix is the palette source on NixOS; end-4 dropped the mode flag which broke dark/light preservation.
- Survives updates: Presence-keyed: added only when the stylix entry / --mode flag is missing.

### config-terminal-defaults
- Target: `ii/modules/common/Config.qml`
- Kind: patch
- Upstream: property real harmony: 0.6 / harmonizeThreshold: 100 / termFgBoost: 0.35
- Ours: harmony: 0.05 / harmonizeThreshold: 40 / termFgBoost: 0.05.
- Why: Near-passthrough harmony keeps the vivid HCT hues' identity (red/blue must not wrap toward the wallpaper accent across the hue seam); minimal boost avoids washed-out fg.
- Survives updates: Exact-string keyed: old values replaced when present.

### workspace-model-special
- Target: `ii/modules/common/models/WorkspaceModel.qml`
- Kind: patch
- Upstream: specialWorkspaceActive: specialWorkspaceName !== '' (name is unreliable; hyprland always reports a specialWorkspace object).
- Ours: Gates the special pill on specialWorkspace?.id !== 0 and blanks the fallback name.
- Why: The pill showed even when no special workspace was open.
- Survives updates: Content-keyed grep, re-applied on update.

### scheme-base
- Target: `ii/scripts/colors/terminal/scheme-base.json`
- Kind: seed
- Upstream: Shipped Gruvbox scheme.
- Ours: Vivid HCT-canonical base: six distinct hues (red 27 / green 145 / yellow 88 / blue 255 / magenta 330 / cyan 190), near-zero-chroma neutrals, near-white term7.
- Why: With near-passthrough harmony these hues keep identity across wallpapers while --blend_bg_fg keeps bg/fg/term15 wallpaper-driven.
- Survives updates: Marker-keyed: overwritten only while it still contains #CC241D (Gruvbox) or lacks our term1 marker, so user edits survive.

### kitty-template
- Target: `ii/scripts/colors/terminal/kitty-theme.conf`
- Kind: patch
- Upstream: foreground/cursor set from $term7 (fixed grey).
- Ours: foreground/cursor set from $onSurface (wallpaper surface, always present in material_colors.scss).
- Why: Kitty fg/cursor should follow the wallpaper surface, not a static grey.
- Survives updates: Content-keyed sed on the '$term7 #' template.

### switchwall-bak-matugen
- Target: `ii/scripts/colors/switchwall.sh.bak`
- Kind: patch
- Upstream: Calls handle_kde_material_you_colors (matugen KDE wrapper, never installed) on every regen.
- Ours: Call disabled.
- Why: It errored every regeneration; enableQtApps=false already short-circuits it, this keeps it inert if Qt theming is re-enabled later.
- Survives updates: Content-keyed sed, re-applied on update.

### switchwall-bak-applycolor
- Target: `ii/scripts/colors/switchwall.sh.bak`
- Kind: patch
- Upstream: Reloads kitty and calls applycolor before the wrapper has rewritten colors.json.
- Ours: Premature applycolor call dropped; wrapper reruns it after the JSON write.
- Why: Kitty reloaded with stale colors on every wallpaper switch.
- Survives updates: Content-keyed sed, re-applied on update.

### shapes
- Target: `ii/modules/common/widgets/shapes`
- Kind: seed
- Upstream: Submodule (rounded-polygon) not populated in the nix input.
- Ours: Copied from the rounded-polygon input.
- Why: The shapes QML components are required by ii widgets.
- Survives updates: Always copied at activation.

### config-json-terminal
- Target: `illogical-impulse/config.json (.appearance.wallpaperTheming.*)`
- Kind: migrate
- Upstream: shipped defaults harmony 0.6/0.25, harmonizeThreshold 100/75, termFgBoost 0.35/0.15, enableQtApps true.
- Ours: harmony=0.05, harmonizeThreshold=40, termFgBoost=0.05, enableQtApps=false.
- Why: Match the near-passthrough terminal defaults; Qt theming bridges via GTK instead.
- Survives updates: Only rewritten when the value still matches a shipped default, preserving user customizations.

### config-json-fullscreen
- Target: `illogical-impulse/config.json (.background.hideWhenFullscreen)`
- Kind: migrate
- Upstream: default true.
- Ours: false.
- Why: hyprpaper is disabled here, so hiding the background layer would leave pure black behind fullscreen windows.
- Survives updates: Only rewritten when true.

### venv
- Target: `~/.local/state/quickshell/.venv`
- Kind: replace
- Upstream: end-4 expects a repo-local venv with materialyoucolor.
- Ours: Bootstrap + repair on every activation: python3 venv, pip install materialyoucolor==2.0.10 pillow numpy opencv-python-headless (g++ on PATH), python.real symlink, LD_LIBRARY_PATH wrappers (libstdc++/libz) that do not leak globally.
- Why: A system python upgrade breaks an existing venv; pip needs a compiler; global LD_LIBRARY_PATH breaks hyprctl.
- Survives updates: Idempotent re-bootstrap every activation.
