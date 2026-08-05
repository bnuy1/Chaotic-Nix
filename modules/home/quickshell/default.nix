{ config, pkgs, lib, inputs, vars, ... }:

let
  cfg = config.programs.quickshell-ii;

  palette = config.lib.stylix.colors;

  # 24h "hh:mm" when clock24h, else 12h "h:mm ap"
  timeFormatDefault =
    if (vars.clock24h or false) then "hh:mm"
    else "h:mm ap";

  # Capitalize the systemFont attr for the fontconfig family name
  fontFamily = let
    s = vars.systemFont or "iosevka";
  in "${lib.toUpper (builtins.substring 0 1 s)}${builtins.substring 1 (builtins.stringLength s) s}";

  # Files/dirs that are "user settings" - never overwritten after first copy
  userFiles = [
    "defaults"
    "settings.qml"
    "GlobalStates.qml"
    "translations"
    ".qmlformat.ini"
  ];

  # Everything else is "code" - always updated from flake
  codeFiles = [
    "modules"
    "panelFamilies"
    "services"
    "scripts"
    "shell.qml"
    "killDialog.qml"
    "ReloadPopup.qml"
    "welcome.qml"
    "assets"
  ];

  # Stylix base16 → MD3 color mapping for quickshell
  stylixColorsJson = builtins.toJSON {
    primary = "#${palette.base0D}";
    on_primary = "#${palette.base00}";
    primary_container = "#${palette.base03}";
    on_primary_container = "#${palette.base0D}";
    primary_fixed = "#${palette.base0D}";
    primary_fixed_dim = "#${palette.base03}";
    on_primary_fixed = "#${palette.base00}";
    on_primary_fixed_variant = "#${palette.base03}";

    secondary = "#${palette.base0E}";
    on_secondary = "#${palette.base00}";
    secondary_container = "#${palette.base04}";
    on_secondary_container = "#${palette.base0E}";
    secondary_fixed = "#${palette.base0E}";
    secondary_fixed_dim = "#${palette.base04}";
    on_secondary_fixed = "#${palette.base00}";
    on_secondary_fixed_variant = "#${palette.base04}";

    tertiary = "#${palette.base0C}";
    on_tertiary = "#${palette.base00}";
    tertiary_container = "#${palette.base04}";
    on_tertiary_container = "#${palette.base0C}";
    tertiary_fixed = "#${palette.base0C}";
    tertiary_fixed_dim = "#${palette.base04}";
    on_tertiary_fixed = "#${palette.base00}";
    on_tertiary_fixed_variant = "#${palette.base04}";

    error = "#${palette.base08}";
    on_error = "#${palette.base00}";
    error_container = "#${palette.base03}";
    on_error_container = "#${palette.base08}";

    success = "#${palette.base0B}";
    on_success = "#${palette.base00}";
    success_container = "#${palette.base03}";
    on_success_container = "#${palette.base0B}";

    background = "#${palette.base00}";
    on_background = "#${palette.base05}";
    surface = "#${palette.base00}";
    on_surface = "#${palette.base05}";
    surface_variant = "#${palette.base02}";
    on_surface_variant = "#${palette.base04}";
    surface_bright = "#${palette.base03}";
    surface_container = "#${palette.base02}";
    surface_container_low = "#${palette.base01}";
    surface_container_lowest = "#${palette.base00}";
    surface_container_high = "#${palette.base03}";
    surface_container_highest = "#${palette.base04}";
    surface_dim = "#${palette.base01}";
    surface_tint = "#${palette.base0D}";

    outline = "#${palette.base03}";
    outline_variant = "#${palette.base02}";
    shadow = "#${palette.base00}";
    scrim = "#${palette.base00}";
    inverse_surface = "#${palette.base05}";
    inverse_on_surface = "#${palette.base01}";
    inverse_primary = "#${palette.base03}";

    # terminal ANSI colors read by applycolor.sh
    # without them kitty-theme.conf keeps the "#$term0 #" placeholders
    term0 = "#${palette.base00}";
    term1 = "#${palette.base08}";
    term2 = "#${palette.base0B}";
    term3 = "#${palette.base0A}";
    term4 = "#${palette.base0D}";
    term5 = "#${palette.base0E}";
    term6 = "#${palette.base0C}";
    term7 = "#${palette.base05}";
    term8 = "#${palette.base03}";
    term9 = "#${palette.base08}";
    term10 = "#${palette.base0B}";
    term11 = "#${palette.base0A}";
    term12 = "#${palette.base0D}";
    term13 = "#${palette.base0E}";
    term14 = "#${palette.base0C}";
    term15 = "#${palette.base07}";
  };
in
{
  options.programs.quickshell-ii = {
    # This module is only reachable from graphical hosts (via hyprland), so
    # importing it implies enabling ii. Set to false to disable on a graphical host.
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Quickshell with end4's Illogical Impulse config";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      quickshell
      matugen
      kdePackages.kdialog
      hyprpicker
      mpvpaper
      ffmpeg
      python3
      python3Packages.pillow

      # Runtime tools called by ii modules and hyprland binds
      grim            # screenshots (ScreenshotAction.qml, Recorder.qml)
      slurp           # region selection (ScreenshotAction.qml)
      swappy          # screenshot editor (TempScreenshotProcess.qml)
      wf-recorder     # screen recording (Recorder.qml, record.sh)
      cliphist        # clipboard history (Cliphist.qml, autostart.lua)
      playerctl       # media keys (binds.lua, MprisController.qml)
      tesseract       # OCR (ScreenshotAction.qml)
      brightnessctl   # brightness keys (binds.lua, Brightness.qml)
      ddcutil         # monitor brightness fallback (Brightness.qml)

      # Fonts required by end4's config
      material-symbols
      nerd-fonts.jetbrains-mono
      twemoji-color-font

      # GSettings for GTK apps (LibreWolf, etc.)
      glib
      gsettings-desktop-schemas

      # For xdg-user-dir (needed by switchwall.sh's Choose file)
      xdg-user-dirs

      # Qt6 modules required by end4's config
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtpositioning
      qt6.qtlocation
      qt6.qtquicktimeline
      qt6.qtsensors
      qt6.qtimageformats
      qt6.qt5compat
      qt6.qtmultimedia
      qt6.qtsvg
      qt6.qttools
      qt6.qttranslations
      qt6.qtvirtualkeyboard
      kdePackages.qtwayland
      kdePackages.kirigami.unwrapped
      kdePackages.syntax-highlighting
    ];

    # Fontconfig for font discovery
    fonts.fontconfig.enable = true;

    home.activation.quickshellConfig = lib.mkAfter ''
      QUICKSHELL_DIR="$HOME/.config/quickshell"
      II_DIR="$QUICKSHELL_DIR/ii"
      SOURCE="${inputs.dots-hyprland}/dots/.config/quickshell/ii"
      mkdir -p "$QUICKSHELL_DIR"

      # Remove symlink if present (leftover from old approach)
      if [ -L "$II_DIR" ]; then
        rm -f "$II_DIR"
      fi

      # First-time setup: copy everything
      if [ ! -d "$II_DIR" ]; then
        cp -r "$SOURCE" "$II_DIR"
        chown -R "$(id -u):$(id -g)" "$II_DIR"
        chmod -R u+w "$II_DIR"
        echo "$SOURCE" > "$II_DIR/.nix-store-path"
      # Update code files if source changed
      elif [ "$(cat "$II_DIR/.nix-store-path" 2>/dev/null)" != "$SOURCE" ]; then
        ${lib.concatMapStringsSep "\n" (f: ''
          if [ -e "$SOURCE/${f}" ]; then
            rm -rf "$II_DIR/${f}"
            cp -r "$SOURCE/${f}" "$II_DIR/${f}"
          fi
        '') codeFiles}

        ${lib.concatMapStringsSep "\n" (f: ''
          if [ ! -e "$II_DIR/${f}" ] && [ -e "$SOURCE/${f}" ]; then
            cp -r "$SOURCE/${f}" "$II_DIR/${f}"
          fi
        '') userFiles}

        chown -R "$(id -u):$(id -g)" "$II_DIR"
        chmod -R u+w "$II_DIR"
        echo "$SOURCE" > "$II_DIR/.nix-store-path"
      fi

      chmod +x "$II_DIR/scripts/"* 2>/dev/null || true

      # Remove the "Random: osu! seasonal" button (osu.ppy.sh API v2 403s
      # without OAuth2; user chose to drop the feature rather than register
      # an OAuth client). Keyed on content so it survives end-4 input updates.
      export QUICKCONFIG_QML="$II_DIR/modules/settings/QuickConfig.qml"
      if [ -f "$QUICKCONFIG_QML" ] && grep -q 'random_osu_wall.sh' "$QUICKCONFIG_QML" 2>/dev/null; then
        python3 << 'PYEOF'
import os
p = os.environ['QUICKCONFIG_QML']
src = open(p).read()
i = src.find('random_osu_wall.sh')
start = src.rfind('RippleButtonWithIcon {', 0, i)
if start != -1:
    depth = 0
    j = start
    while j < len(src):
        if src[j] == '{':
            depth += 1
        elif src[j] == '}':
            depth -= 1
            if depth == 0:
                break
        j += 1
    end = j + 1
    while end < len(src) and src[end] in ' \t':
        end += 1
    if end < len(src) and src[end] == '\n':
        end += 1
    open(p, 'w').write(src[:start] + src[end:])
PYEOF
      fi

      # Copy shapes submodule
      SHAPES_DIR="$II_DIR/modules/common/widgets/shapes"
      mkdir -p "$SHAPES_DIR" 2>/dev/null || true
      cp -r "${inputs.rounded-polygon}/"* "$SHAPES_DIR/" 2>/dev/null || true
      chown -R "$(stat -c '%u:%g' "$HOME")" "$SHAPES_DIR" 2>/dev/null || true
      chmod -R u+w "$SHAPES_DIR" 2>/dev/null || true

      # Always update our wrapper script
      rm -f "$QUICKSHELL_DIR/launch.sh" 2>/dev/null || true
      cp ${./launch.sh} "$QUICKSHELL_DIR/launch.sh" 2>/dev/null || true
      chmod +x "$QUICKSHELL_DIR/launch.sh" 2>/dev/null || true

      # Generate Stylix color palette for quickshell (MD3-compatible)
      # Place alongside MaterialThemeLoader's colors.json path
      STATE_GEN_DIR="$HOME/.local/state/quickshell/user/generated"
      mkdir -p "$STATE_GEN_DIR"
      cat > "$STATE_GEN_DIR/stylix-colors.json" << 'STYLIX_EOF'
      ${stylixColorsJson}
STYLIX_EOF
      chown "$(stat -c '%u:%g' "$HOME")" "$STATE_GEN_DIR/stylix-colors.json"

      # Deploy the latest apply-app-themes.sh into the ii dir and chmod +x.
      # A raw ''${./file} reference copies to the store as 0644, so the wrapper
      # and this activation could never execute it (silently, due to `|| true`).
      mkdir -p "$II_DIR/scripts/colors" 2>/dev/null || true
      rm -f "$II_DIR/scripts/colors/apply-app-themes.sh" 2>/dev/null || true
      cp ${./apply-app-themes.sh} "$II_DIR/scripts/colors/apply-app-themes.sh" 2>/dev/null || true
      chmod +x "$II_DIR/scripts/colors/apply-app-themes.sh" 2>/dev/null || true
      chown "$(stat -c '%u:%g' "$HOME")" "$II_DIR/scripts/colors/apply-app-themes.sh" 2>/dev/null || true

      # Deploy the patched color generator. Upstream only harmonizes terminal
      # colors toward the primary hue (a no-op at harmony=0.05), so the
      # terminal never follows the wallpaper or the palette mode. The patched
      # version rotates the six vivid ANSI hues with the scheme's primary hue.
      rm -f "$II_DIR/scripts/colors/generate_colors_material.py" 2>/dev/null || true
      cp ${./scripts/generate_colors_material.py} "$II_DIR/scripts/colors/generate_colors_material.py" 2>/dev/null || true
      chmod +x "$II_DIR/scripts/colors/generate_colors_material.py" 2>/dev/null || true
      chown "$(stat -c '%u:%g' "$HOME")" "$II_DIR/scripts/colors/generate_colors_material.py" 2>/dev/null || true

      # Pre-generate app themes (fuzzel/gtk/foot/fish/wlogout) at activation so
      # they exist before the first palette sync. Without this, foot refuses to
      # start (its include file is missing). Falls back to Stylix colors; the
      # runtime palette overwrites these after the first quickshell color sync.
      if [ ! -s "$STATE_GEN_DIR/colors.json" ] && [ -s "$STATE_GEN_DIR/stylix-colors.json" ]; then
        cp "$STATE_GEN_DIR/stylix-colors.json" "$STATE_GEN_DIR/colors.json"
        chown "$(stat -c '%u:%g' "$HOME")" "$STATE_GEN_DIR/colors.json"
      fi
      bash "$II_DIR/scripts/colors/apply-app-themes.sh" >/dev/null 2>&1 || true

      # Copy ColorSourceBridge (watches palette type & wallpaper changes)
      # Try non-interactive sudo if II_DIR is not writable (transition from root-owned files)
      if [ ! -w "$II_DIR/services" ] 2>/dev/null && ! [ -w "$II_DIR" ] 2>/dev/null; then
        sudo -n chown -R "$(stat -c '%u:%g' "$HOME")" "$II_DIR" 2>/dev/null || true
      fi
      mkdir -p "$II_DIR/services" 2>/dev/null || true
      rm -f "$II_DIR/services/ColorSourceBridge.qml" 2>/dev/null || true
      cp ${./ColorSourceBridge.qml} "$II_DIR/services/ColorSourceBridge.qml" 2>/dev/null || true
      chown "$(stat -c '%u:%g' "$HOME")" "$II_DIR/services/ColorSourceBridge.qml" 2>/dev/null || true
      rm -f "$II_DIR/services/MaterialThemeLoader.qml" 2>/dev/null || true
      cp ${./MaterialThemeLoader.qml} "$II_DIR/services/MaterialThemeLoader.qml" 2>/dev/null || true
      chown "$(stat -c '%u:%g' "$HOME")" "$II_DIR/services/MaterialThemeLoader.qml" 2>/dev/null || true

      # Patch QuickConfig.qml to add "Stylix" palette option and fix onSelected
      # Use Python for reliable multi-line editing
      export QS_II_DIR="$II_DIR"
      python3 << 'PYEOF' 2>/dev/null || true
import re, os
path = os.environ['QS_II_DIR'] + '/modules/settings/QuickConfig.qml'
with open(path) as f:
    content = f.read()

# Remove any existing broken stylix entry from previous bad sed
content = re.sub(r',\s*,\s*\{\s*"value":\s*"stylix".*?\}', ',', content, flags=re.DOTALL)

# Fix onSelected to pass --type and --mode flags to switchwall (preserve dark/light mode)
D = '$'
old_sel = 'Quickshell.execDetached(["bash", "-c", `' + D + '{Directories.wallpaperSwitchScriptPath} --noswitch`]);'
new_sel = 'const mode = Appearance.m3colors.darkmode ? "dark" : "light";\n                Quickshell.execDetached(["bash", "-c", `' + D + '{Directories.wallpaperSwitchScriptPath} --noswitch --type ' + D + '{newValue} --mode ' + D + '{mode}`]);'
if 'onSelected' in content:
    on_sel = content[content.index('onSelected'):content.index('\n', content.index('onSelected'))]
    if '--mode' not in on_sel:
        old_with_type = 'Quickshell.execDetached(["bash", "-c", `' + D + '{Directories.wallpaperSwitchScriptPath} --noswitch --type ' + D + '{newValue}`]);'
        if old_with_type in content:
            content = content.replace(old_with_type, new_sel)
        elif old_sel in content:
            content = content.replace(old_sel, new_sel)

# Add stylix entry after 'tonal-spot' if not already present
if '"value": "stylix"' not in content:
    pattern = r'(\s*\{\s*"value":\s*"scheme-tonal-spot".*?\},)'
    replacement = r'\1\n                ,\n                {\n                    "value": "stylix",\n                    "displayName": Translation.tr("Stylix")\n                }'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(path, 'w') as f:
    f.write(content)
PYEOF

      # Patch Config.qml to use better terminal color defaults
      python3 -c "
path = '$II_DIR/modules/common/Config.qml'
with open(path) as f:
    content = f.read()

# Better terminal color defaults: near-passthrough harmony so the vivid
# HCT base keeps its hue identity (red/blue must not wrap across the hue
# wheel seam toward the wallpaper accent), minimal boost (not washed out)
old_harmony = 'property real harmony: 0.6'
new_harmony = 'property real harmony: 0.05'
old_threshold = 'property real harmonizeThreshold: 100'
new_threshold = 'property real harmonizeThreshold: 40'
old_boost = 'property real termFgBoost: 0.35'
new_boost = 'property real termFgBoost: 0.05'
if old_harmony in content:
    content = content.replace(old_harmony, new_harmony)
if old_threshold in content:
    content = content.replace(old_threshold, new_threshold)
if old_boost in content:
    content = content.replace(old_boost, new_boost)

# Default clock format follows the clock24h variable (12h AM/PM vs 24h)
old_time_fmt = 'property string format: "hh:mm"'
new_time_fmt = 'property string format: "${timeFormatDefault}"'
content = content.replace(old_time_fmt, new_time_fmt)

# keep the background layer visible on fullscreen
# hyprpaper is disabled here so hiding it would leave pure black
old_fullscreen = 'property bool hideWhenFullscreen: true'
new_fullscreen = 'property bool hideWhenFullscreen: false'
content = content.replace(old_fullscreen, new_fullscreen)

# Use Iosevka as the font family everywhere in the defaults
for old_font, new_font in {
  'property string main: "Google Sans Flex"': 'property string main: "${fontFamily}"',
  'property string numbers: "Google Sans Flex"': 'property string numbers: "${fontFamily}"',
  'property string title: "Google Sans Flex"': 'property string title: "${fontFamily}"',
  'property string iconNerd: "JetBrains Mono NF"': 'property string iconNerd: "${fontFamily}"',
  'property string monospace: "JetBrains Mono NF"': 'property string monospace: "${fontFamily}"',
  'property string reading: "Readex Pro"': 'property string reading: "${fontFamily}"',
  'property string expressive: "Space Grotesk"': 'property string expressive: "${fontFamily}"',
  'property string family: "Google Sans Flex"': 'property string family: "${fontFamily}"',
}.items():
    content = content.replace(old_font, new_font)

with open(path, 'w') as f:
    f.write(content)
" 2>/dev/null || true

      # Patch ReloadPopup.qml to use Iosevka everywhere too
      python3 -c "
path = '$II_DIR/ReloadPopup.qml'
with open(path) as f:
    content = f.read()
content = content.replace('font.family: \"Google Sans Flex\"', 'font.family: \"${fontFamily}\"')
content = content.replace('font.family: \"JetBrains Mono NF\"', 'font.family: \"${fontFamily}\"')
with open(path, 'w') as f:
    f.write(content)
" 2>/dev/null || true

      # Patch About.qml for bnuynix branding (assets-based distro icon + links)
      export QS_II_DIR="$II_DIR"
      python3 << 'PYEOF' 2>/dev/null || true
import os
path = os.environ['QS_II_DIR'] + '/modules/settings/About.qml'
with open(path) as f:
    content = f.read()

# Distro icon: resolve from theme assets instead of the system icon theme
content = content.replace(
    'source: Quickshell.iconPath(SystemInfo.logo)',
    'source: Quickshell.shellPath("assets/icons/" + SystemInfo.logo + ".svg")')

# Dotfiles section: github icon + bnuynix name
content = content.replace(
    'source: Quickshell.iconPath("illogical-impulse")',
    'source: Quickshell.shellPath("assets/icons/github-symbolic.svg")')
content = content.replace(
    'text: Translation.tr("illogical-impulse")',
    'text: Translation.tr("bnuynix")')

# Swap Discussions -> Website, drop Donate
discussions_block = (
    'RippleButtonWithIcon {\n'
    '                materialIcon: "forum"\n'
    '                mainText: Translation.tr("Discussions")\n'
    '                onClicked: {\n'
    '                    Qt.openUrlExternally("https://github.com/end-4/dots-hyprland/discussions")\n'
    '                }\n'
    '            }')
website_block = (
    'RippleButtonWithIcon {\n'
    '                materialIcon: "language"\n'
    '                mainText: Translation.tr("Website")\n'
    '                onClicked: {\n'
    '                    Qt.openUrlExternally("https://bnuy.dev")\n'
    '                }\n'
    '            }')
content = content.replace(discussions_block, website_block)
donate_block = (
    '            RippleButtonWithIcon {\n'
    '                materialIcon: "favorite"\n'
    '                mainText: Translation.tr("Donate")\n'
    '                onClicked: {\n'
    '                    Qt.openUrlExternally("https://github.com/sponsors/end-4")\n'
    '                }\n'
    '            }\n')
content = content.replace(donate_block, "")

# Drop Help & Support and Privacy Policy buttons from the Distro section
help_support_block = (
    '            RippleButtonWithIcon {\n'
    '                materialIcon: "support"\n'
    '                mainText: Translation.tr("Help & Support")\n'
    '                onClicked: {\n'
    '                    Qt.openUrlExternally(SystemInfo.supportUrl)\n'
    '                }\n'
    '            }\n')
content = content.replace(help_support_block, "")
privacy_block = (
    '            RippleButtonWithIcon {\n'
    '                materialIcon: "policy"\n'
    '                materialIconFill: false\n'
    '                mainText: Translation.tr("Privacy Policy")\n'
    '                onClicked: {\n'
    '                    Qt.openUrlExternally(SystemInfo.privacyPolicyUrl)\n'
    '                }\n'
    '            }\n')
content = content.replace(privacy_block, "")

# Point remaining end-4 links at bnuynix
content = content.replace('https://github.com/end-4/dots-hyprland', 'https://github.com/bnuy1/bnuynix')
content = content.replace('https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/', 'https://github.com/bnuy1/bnuynix')

with open(path, 'w') as f:
    f.write(content)
PYEOF

      # Wrap switchwall.sh to handle "stylix" palette type
      # Original is saved as switchwall.sh.bak
      # Back up the original if not already done
      if [ -f "$II_DIR/scripts/colors/switchwall.sh" ] && \
         ! grep -q "stylix wrapper" "$II_DIR/scripts/colors/switchwall.sh" 2>/dev/null; then
        cp "$II_DIR/scripts/colors/switchwall.sh" "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null || true
      fi
      # Recover corrupted .bak from flake source if needed
      if [ -f "$SOURCE/scripts/colors/switchwall.sh" ] && \
         [ -f "$II_DIR/scripts/colors/switchwall.sh.bak" ] && \
         ! head -1 "$II_DIR/scripts/colors/switchwall.sh.bak" | grep -q "switchwall.sh" 2>/dev/null; then
        cp "$SOURCE/scripts/colors/switchwall.sh" "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null || true
      fi
      # Always install/update the wrapper
      cat > "$II_DIR/scripts/colors/switchwall.sh" << 'WRAPPER'
#!/usr/bin/env bash
# stylix wrapper for switchwall.sh v3
# Handles "stylix" palette type; delegates to original for everything else
# Accepts --type flag (recommended) or falls back to config file
# Sets LD_LIBRARY_PATH for pip-installed native extensions (libstdc++)
# Caches color gen result to speed up subsequent startups

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
QUICKSHELL_CONFIG_NAME="ii"
if [ -z "$XDG_CONFIG_HOME" ]; then XDG_CONFIG_HOME="$HOME/.config"; fi
if [ -z "$XDG_STATE_HOME" ]; then XDG_STATE_HOME="$HOME/.local/state"; fi
STATE_DIR="$XDG_STATE_HOME/quickshell"
GEN_DIR="$STATE_DIR/user/generated"
SHELL_CONFIG="$XDG_CONFIG_HOME/illogical-impulse/config.json"
ORIGINAL="$SCRIPT_DIR/switchwall.sh.bak"

# serialize concurrent runs so parallel writes stay whole
LOCK_FILE="$GEN_DIR/.switchwall.lock"
mkdir -p "$GEN_DIR" 2>/dev/null || true
exec 9>"$LOCK_FILE"
flock -x 9
if [ -z "''${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]; then
  ILLOGICAL_IMPULSE_VIRTUAL_ENV="$HOME/.local/state/quickshell/.venv"
  export ILLOGICAL_IMPULSE_VIRTUAL_ENV
fi

RELOAD_HOOK="quickshell -c ii ipc call theme applyTheme 2>/dev/null || true"

LOG_FILE="$GEN_DIR/.wallpaper-cache.log"
log_cache() {
  mkdir -p "$GEN_DIR" 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# do not export LD_LIBRARY_PATH here
# a global one breaks every hyprctl call
# the venv python entrypoints set their own LD_LIBRARY_PATH

detect_stylix() {
  while [[ $# -gt 1 ]]; do
    if [ "$1" = "--type" ]; then
      [ "$2" = "stylix" ] && return 0 || return 1
    fi
    shift
  done
  [ "$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG" 2>/dev/null)" = "stylix" ]
}

# Cache key: effective wallpaper + palette type + dark/light mode + terminal props
compute_cache_key() {
    local wp=""
    local mode=""
    local ptype=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --image) wp="$2"; shift 2 ;;
        --mode) mode="$2"; shift 2 ;;
        --type) ptype="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -z "$wp" ]] && wp=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG" 2>/dev/null)
    [[ -z "$ptype" ]] && ptype=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG" 2>/dev/null)
    [[ -z "$mode" ]] && mode=$(jq -r '.appearance.palette.mode // "dark"' "$SHELL_CONFIG" 2>/dev/null)
    local harmony harmonize_threshold term_fg_boost
    harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony // "0.1"' "$SHELL_CONFIG" 2>/dev/null)
    harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // "15"' "$SHELL_CONFIG" 2>/dev/null)
    term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // "0.05"' "$SHELL_CONFIG" 2>/dev/null)
    echo "$wp|$ptype|$mode|$harmony|$harmonize_threshold|$term_fg_boost" | md5sum | cut -d' ' -f1
}

check_cache() {
    local key
    key=$(compute_cache_key "$@")
    local cache_file="$GEN_DIR/.wallpaper-cache"
    [[ -f "$cache_file" && "$(cat "$cache_file" 2>/dev/null)" = "$key" ]]
}

write_cache() {
    local key
    key=$(compute_cache_key "$@")
    echo "$key" > "$GEN_DIR/.wallpaper-cache"
}

# Force sane terminal color generation. The shipped end-4 defaults
# (harmony 0.8 / threshold 10 / boost 0.3) wash the base scheme toward the
# wallpaper accent. The patched generator now rotates the six chroma ANSI
# hues with the scheme's primary hue (fixed 40° offsets, chroma >= 90), so
# they follow the wallpaper AND the palette mode while staying distinct;
# harmony is kept at a near-passthrough 0.05 so the neutral slots
# (term7/term8) don't shift, and bg/fg/term15 still follow the wallpaper
# via --blend_bg_fg. enableQtApps=false also neuters the broken KDE
# material wrapper call.
set_terminal_defaults() {
    jq '.appearance.wallpaperTheming.terminalGenerationProps.harmony = 0.05
        | .appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = 40
        | .appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = 0.05
        | .appearance.wallpaperTheming.enableQtApps = false' "$SHELL_CONFIG" \
        > "''${SHELL_CONFIG}.tmp" && mv "''${SHELL_CONFIG}.tmp" "$SHELL_CONFIG" 2>/dev/null || true
}

# Check for --no-cache flag to force regeneration
NO_CACHE=false
FWD_ARGS=()
HAS_NOSWITCH=false
for arg in "$@"; do
  if [ "$arg" = "--no-cache" ]; then
    NO_CACHE=true
  else
    FWD_ARGS+=("$arg")
    [ "$arg" = "--noswitch" ] && HAS_NOSWITCH=true
  fi
done

# If --mode isn't passed, inject one so the original never falls back to
# gsettings (which is unavailable on NixOS and defaults to LIGHT)
if ! printf '%s\0' "''${FWD_ARGS[@]}" | grep -qz -- '--mode'; then
  MODE_FALLBACK=$(jq -r '.appearance.palette.mode // "dark"' "$SHELL_CONFIG" 2>/dev/null)
  [[ -z "$MODE_FALLBACK" || "$MODE_FALLBACK" == "null" ]] && MODE_FALLBACK="dark"
  FWD_ARGS+=(--mode "$MODE_FALLBACK")
fi

if detect_stylix "''${FWD_ARGS[@]}"; then
  mkdir -p "$GEN_DIR" 2>/dev/null || true
  log_cache "stylix | args=''${FWD_ARGS[*]}"
  if [ -f "$ORIGINAL" ]; then
    bash "$ORIGINAL" "''${FWD_ARGS[@]}" 2>/dev/null || true
  fi
  cp "$GEN_DIR/stylix-colors.json" "$GEN_DIR/colors.json.tmp.$$" 2>/dev/null \
    && mv -f "$GEN_DIR/colors.json.tmp.$$" "$GEN_DIR/colors.json" 2>/dev/null || true
  bash "$SCRIPT_DIR/apply-app-themes.sh" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/applycolor.sh" >/dev/null 2>&1 || true
  write_cache "''${FWD_ARGS[@]}"
  eval "$RELOAD_HOOK"
  exit 0
fi

# Cache ONLY --noswitch calls (quiet startup syncs). User actions such as
# the interactive file picker (no args) or --image applies must always run.
if $HAS_NOSWITCH && ! $NO_CACHE && check_cache "''${FWD_ARGS[@]}" && [ -s "$GEN_DIR/colors.json" ]; then
  # Cache hit - just trigger reload with existing colors
  log_cache "CACHE HIT | key=$(cat "$GEN_DIR/.wallpaper-cache" 2>/dev/null) | args=''${FWD_ARGS[*]}"
  bash "$SCRIPT_DIR/apply-app-themes.sh" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/applycolor.sh" >/dev/null 2>&1 || true
  eval "$RELOAD_HOOK"
  exit 0
fi

# Full regeneration
log_cache "CACHE MISS (regenerating) | args=''${FWD_ARGS[*]}"

# Set better defaults for terminal colors
set_terminal_defaults

# Delegate to original, then convert SCSS→JSON for MaterialThemeLoader
if [ -f "$ORIGINAL" ]; then
  bash "$ORIGINAL" "''${FWD_ARGS[@]}" || true

  SCSS_FILE="$GEN_DIR/material_colors.scss"
  JSON_FILE="$GEN_DIR/colors.json"
  if [ -s "$SCSS_FILE" ]; then
    export SCSS_FILE JSON_FILE
    python3 << 'PYEOF'
import re, json, os
scss = open(os.environ['SCSS_FILE']).read()
colors = {}
for m in re.finditer(r'^\$(\w+):\s*(#[A-Fa-f0-9]+);', scss, re.MULTILINE):
    name, val = m.groups()
    if name not in ('darkmode', 'transparent'):
        colors[name] = val
import tempfile
p = os.environ['JSON_FILE']
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p), suffix='.tmp')
with os.fdopen(fd, 'w') as f:
    json.dump(colors, f)
os.replace(tmp, p)
PYEOF
  fi
  # rerun applycolor after the conversion so kitty themes come from the new colors
  bash "$SCRIPT_DIR/applycolor.sh" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/apply-app-themes.sh" >/dev/null 2>&1 || true
  write_cache "''${FWD_ARGS[@]}"
  eval "$RELOAD_HOOK"
else
  echo "switchwall.sh: original not found at $ORIGINAL" >&2
  exit 1
fi
WRAPPER
      chmod +x "$II_DIR/scripts/colors/switchwall.sh" 2>/dev/null || true

      # deploy our applycolor.sh
      # the end-4 version only runs on full regeneration and breaks the kitty reload
      # ours reads colors json directly so it works on cached syncs too
      mkdir -p "$II_DIR/scripts/colors" 2>/dev/null || true
      rm -f "$II_DIR/scripts/colors/applycolor.sh" 2>/dev/null || true
      cp ${./scripts/applycolor.sh} "$II_DIR/scripts/colors/applycolor.sh" 2>/dev/null || true
      chmod +x "$II_DIR/scripts/colors/applycolor.sh" 2>/dev/null || true
      chown "$(stat -c '%u:%g' "$HOME")" "$II_DIR/scripts/colors/applycolor.sh" 2>/dev/null || true

      # show the special pill only when a special workspace is open
      # hyprland always reports a specialWorkspace object so gate on its id
      # instead of its name which is unreliable
      WORKSPACE_MODEL_QML="$II_DIR/modules/common/models/WorkspaceModel.qml"
      if [ -f "$WORKSPACE_MODEL_QML" ] && \
         grep -q 'specialWorkspaceActive: specialWorkspaceName !== ""' "$WORKSPACE_MODEL_QML" 2>/dev/null; then
        export WORKSPACE_MODEL_QML
        python3 << 'PYEOF'
import os
p = os.environ['WORKSPACE_MODEL_QML']
src = open(p).read()
src = src.replace(
    'specialWorkspace?.name.replace("special:", "") ?? "special"',
    'specialWorkspace?.name?.replace("special:", "") ?? ""')
src = src.replace(
    'specialWorkspaceActive: specialWorkspaceName !== ""',
    'specialWorkspaceActive: specialWorkspace?.id !== 0 && specialWorkspaceName !== ""')
open(p, 'w').write(src)
PYEOF
      fi

      # Replace the shipped Gruvbox terminal scheme with a vivid HCT-canonical
      # base: six distinct hues (red 27 / green 145 / yellow 88 / blue 255 /
      # magenta 330 / cyan 190), near-zero-chroma neutrals, near-white term7.
      # With the near-passthrough harmony forced above, these hues keep their
      # identity across wallpapers while --blend_bg_fg keeps bg/fg/term15
      # wallpaper-driven. Keyed on our term1 marker so end-4 input updates
      # can't restore Gruvbox without re-clobbering our file.
      SCHEME_FILE="$II_DIR/scripts/colors/terminal/scheme-base.json"
      if [ -f "$SCHEME_FILE" ]; then
        if ! grep -qF '"term1"' "$SCHEME_FILE" || grep -qF '#CC241D' "$SCHEME_FILE"; then
          cat > "$SCHEME_FILE" << 'SCHEME_JSON'
{
  "dark": {
    "term0": "#131313",
    "term1": "#FF614E",
    "term2": "#00AE2B",
    "term3": "#C89A00",
    "term4": "#1A9AFF",
    "term5": "#F158FF",
    "term6": "#00AEA4",
    "term7": "#F3F3F3",
    "term8": "#8B8B8B",
    "term9": "#FF816F",
    "term10": "#06C634",
    "term11": "#E3AE00",
    "term12": "#67AFFF",
    "term13": "#F779FF",
    "term14": "#00BFB5",
    "term15": "#FCFCFC"
  },
  "light": {
    "term0": "#F9F9F9",
    "term1": "#C5180F",
    "term2": "#007419",
    "term3": "#8F6D00",
    "term4": "#006DBA",
    "term5": "#B800CB",
    "term6": "#007871",
    "term7": "#353535",
    "term8": "#7C7C7C",
    "term9": "#8B0001",
    "term10": "#004E0E",
    "term11": "#654C00",
    "term12": "#00497F",
    "term13": "#7D008B",
    "term14": "#00504B",
    "term15": "#1B1B1B"
  }
}
SCHEME_JSON
        fi
      fi

      # Kitty template: foreground/cursor should follow the wallpaper surface
      # (bright, non-grey) instead of $term7. onSurface is material's
      # foreground and is always present in material_colors.scss, so
      # applycolor.sh fills it the same way as the $termN tokens.
      KITTY_TEMPLATE="$II_DIR/scripts/colors/terminal/kitty-theme.conf"
      if [ -f "$KITTY_TEMPLATE" ] && grep -qF 'foreground            #$term7 #' "$KITTY_TEMPLATE" 2>/dev/null; then
        sed -i -e 's/foreground            #\$term7 #/foreground            #$onSurface #/' \
               -e 's/^cursor                #\$term7 #/cursor                #$onSurface #/' \
               "$KITTY_TEMPLATE" 2>/dev/null || true
      fi

      # The end-4 switchwall.sh.bak calls handle_kde_material_you_colors (a
      # matugen KDE wrapper that is never installed), which errors every
      # regen. enableQtApps=false (forced in set_terminal_defaults) already
      # short-circuits it; drop the call so it stays inert even if Qt
      # theming is re-enabled later.
      if [ -f "$II_DIR/scripts/colors/switchwall.sh.bak" ] && \
         grep -qF '    handle_kde_material_you_colors &' "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null; then
        sed -i 's|^    handle_kde_material_you_colors &$|    # handle_kde_material_you_colors disabled: matugen KDE wrapper is not installed|' "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null || true
      fi

      # the .bak reloads kitty before the wrapper rewrites colors json so
      # the premature applycolor call is dropped here and rerun after the write
      if [ -f "$II_DIR/scripts/colors/switchwall.sh.bak" ] && \
         grep -qF '    "$SCRIPT_DIR"/applycolor.sh' "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null; then
        sed -i 's|^    "\$SCRIPT_DIR"/applycolor.sh$|    # applycolor disabled here the wrapper reruns it after writing colors json|' "$II_DIR/scripts/colors/switchwall.sh.bak" 2>/dev/null || true
      fi

      # use hardened random wallpaper scripts
      # the shipped scripts fed empty files to switchwall and crashed the shell
      mkdir -p "$II_DIR/scripts/colors/random" 2>/dev/null || true
      cp ${./scripts/random_konachan_wall.sh} "$II_DIR/scripts/colors/random/random_konachan_wall.sh" 2>/dev/null || true
      chmod +x "$II_DIR/scripts/colors/random/"*.sh 2>/dev/null || true

      # venv needs a compiler to build the materialyoucolor extension
      # so g++ is put on PATH here before pip install
      VENV_DIR="$HOME/.local/state/quickshell/.venv"
      # a system python upgrade breaks an existing venv
      # so the venv is bootstrapped and repaired on every activation
      if [ ! -f "$VENV_DIR/bin/activate" ]; then
        ${pkgs.python3}/bin/python3 -m venv --prompt .venv "$VENV_DIR" 2>/dev/null || true
      fi
      # venv pip packages need libstdc++ and libz at runtime
      # do not export LD_LIBRARY_PATH globally or hyprctl breaks
      # the venv python wrappers set it only for their own process
      # the activation PATH has no python3 so resolve it via the store path
      PY_LD="${pkgs.stdenv.cc.cc.lib}/lib"
      REAL_PY="$(readlink -f "${pkgs.python3}/bin/python3" 2>/dev/null || true)"
      if [ -n "$REAL_PY" ] && [ -x "$REAL_PY" ]; then
        # wrapper scripts exec this symlink not the realpath
        # the symlink is what makes CPython detect the venv
        ln -sfn "$REAL_PY" "$VENV_DIR/bin/python.real" 2>/dev/null || true
        for p in "$VENV_DIR"/bin/python*; do
          name="$(basename "$p")"
          [ "$name" = "python.real" ] && continue
          [ "$name" = "python-config" ] && continue
          [ -e "$p" ] || continue
          rm -f "$p"
          cat > "$p" << 'PYWRAPEOF'
#!/usr/bin/env bash
# quickshell-venv-python
export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}__PY_LD__"
exec "__VENV_DIR__/bin/python.real" "$@"
PYWRAPEOF
          sed -i "s|__PY_LD__|$PY_LD|g; s|__VENV_DIR__|$VENV_DIR|g" "$p" 2>/dev/null || true
          chmod +x "$p"
        done
      fi
      # re-bootstrap the venv when its pip is broken or missing
      if ! "$VENV_DIR/bin/pip" --version >/dev/null 2>&1; then
        "$VENV_DIR/bin/python" -m ensurepip 2>/dev/null || true
        "$VENV_DIR/bin/python" -m pip install -q --upgrade pip 2>/dev/null || true
      fi
      if ! "$VENV_DIR/bin/python" -c 'import materialyoucolor, PIL, numpy, cv2' >/dev/null 2>&1; then
        PATH="${pkgs.stdenv.cc}/bin:''${PATH}" "$VENV_DIR/bin/pip" install -q \
          "materialyoucolor==2.0.10" pillow numpy opencv-python-headless 2>/dev/null || \
        PATH="${pkgs.stdenv.cc}/bin:''${PATH}" "$VENV_DIR/bin/pip" install -q \
          --break-system-packages "materialyoucolor==2.0.10" pillow numpy opencv-python-headless 2>/dev/null || true
      fi

      # Migrate terminal generation props to the vivid near-passthrough
      # defaults (harmony=0.05, threshold=40, boost=0.05) and disable Qt
      # theming. Only update values that still match previously shipped
      # defaults (0.6 or 0.25 harmony, etc.), preserving user customizations.
      SHELL_CONFIG_JSON="''${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
      if [ -f "$SHELL_CONFIG_JSON" ]; then
        jq '
          if (.appearance.wallpaperTheming.terminalGenerationProps.harmony // 0) == 0.6 or
             (.appearance.wallpaperTheming.terminalGenerationProps.harmony // 0) == 0.25 then
            .appearance.wallpaperTheming.terminalGenerationProps.harmony = 0.05
          else . end
          | if (.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // 0) == 100 or
               (.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // 0) == 75 then
            .appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = 40
          else . end
          | if (.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // 0) == 0.35 or
               (.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // 0) == 0.15 then
            .appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = 0.05
          else . end
          | .appearance.wallpaperTheming.enableQtApps = false
        ' "$SHELL_CONFIG_JSON" > "$SHELL_CONFIG_JSON.tmp" 2>/dev/null && mv "$SHELL_CONFIG_JSON.tmp" "$SHELL_CONFIG_JSON" 2>/dev/null || true
      fi

      # keep the background layer alive on fullscreen
      # hyprpaper is disabled here so hiding it would leave pure black
      if [ -f "$SHELL_CONFIG_JSON" ] && [ "$(jq -r '.background.hideWhenFullscreen // false' "$SHELL_CONFIG_JSON" 2>/dev/null)" = "true" ]; then
        jq '.background.hideWhenFullscreen = false' "$SHELL_CONFIG_JSON" > "$SHELL_CONFIG_JSON.tmp" 2>/dev/null \
          && mv "$SHELL_CONFIG_JSON.tmp" "$SHELL_CONFIG_JSON" 2>/dev/null || true
      fi
    '';
  };
}
