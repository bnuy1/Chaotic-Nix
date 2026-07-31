{ config, pkgs, lib, inputs, vars, ... }:

let
  cfg = config.programs.quickshell-ii;

  palette = config.lib.stylix.colors;

  # Default clock format follows the clock24h variable:
  # true  -> 24-hour "hh:mm", false -> 12-hour AM/PM "h:mm ap"
  timeFormatDefault =
    if (vars.clock24h or false) then "hh:mm"
    else "h:mm ap";

  # vars.systemFont is the nix package attr ("iosevka"); the fontconfig
  # family name is the capitalized form ("Iosevka")
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
  };
in
{
  options.programs.quickshell-ii = {
    enable = lib.mkEnableOption "Quickshell with end4's Illogical Impulse config";
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

# Better terminal color defaults: less harmony (more distinct hues), less boost (not washed out)
old_harmony = 'property real harmony: 0.6'
new_harmony = 'property real harmony: 0.25'
old_threshold = 'property real harmonizeThreshold: 100'
new_threshold = 'property real harmonizeThreshold: 75'
old_boost = 'property real termFgBoost: 0.35'
new_boost = 'property real termFgBoost: 0.15'
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
      STDCXX_LIB="${pkgs.stdenv.cc.cc.lib}/lib"
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

STDCXX_LIB="__STDCXX_LIB__"
export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$STDCXX_LIB"

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
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --image) wp="$2"; shift 2 ;;
        --mode) mode="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -z "$wp" ]] && wp=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG" 2>/dev/null)
    local ptype
    ptype=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG" 2>/dev/null)
    [[ -z "$mode" ]] && mode=$(jq -r '.appearance.palette.mode // "dark"' "$SHELL_CONFIG" 2>/dev/null)
    local harmony harmonize_threshold term_fg_boost
    harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony // "0.25"' "$SHELL_CONFIG" 2>/dev/null)
    harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // "75"' "$SHELL_CONFIG" 2>/dev/null)
    term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // "0.15"' "$SHELL_CONFIG" 2>/dev/null)
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

# Set better terminal color defaults (less harmony, less boost)
set_terminal_defaults() {
    # Only set if not already explicitly configured
    local harmony harmonize_threshold term_fg_boost
    harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony // "null"' "$SHELL_CONFIG" 2>/dev/null)
    harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // "null"' "$SHELL_CONFIG" 2>/dev/null)
    term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // "null"' "$SHELL_CONFIG" 2>/dev/null)
    [[ "$harmony" == "null" || -z "$harmony" ]] && jq '.appearance.wallpaperTheming.terminalGenerationProps.harmony = 0.25' "$SHELL_CONFIG" > "''${SHELL_CONFIG}.tmp" && mv "''${SHELL_CONFIG}.tmp" "$SHELL_CONFIG" 2>/dev/null || true
    [[ "$harmonize_threshold" == "null" || -z "$harmonize_threshold" ]] && jq '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = 75' "$SHELL_CONFIG" > "''${SHELL_CONFIG}.tmp" && mv "''${SHELL_CONFIG}.tmp" "$SHELL_CONFIG" 2>/dev/null || true
    [[ "$term_fg_boost" == "null" || -z "$term_fg_boost" ]] && jq '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = 0.15' "$SHELL_CONFIG" > "''${SHELL_CONFIG}.tmp" && mv "''${SHELL_CONFIG}.tmp" "$SHELL_CONFIG" 2>/dev/null || true
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
  cp "$GEN_DIR/stylix-colors.json" "$GEN_DIR/colors.json" 2>/dev/null || true
  write_cache "''${FWD_ARGS[@]}"
  eval "$RELOAD_HOOK"
  exit 0
fi

# Cache ONLY --noswitch calls (quiet startup syncs). User actions such as
# the interactive file picker (no args) or --image applies must always run.
if $HAS_NOSWITCH && ! $NO_CACHE && check_cache "''${FWD_ARGS[@]}" && [ -s "$GEN_DIR/colors.json" ]; then
  # Cache hit - just trigger reload with existing colors
  log_cache "CACHE HIT | key=$(cat "$GEN_DIR/.wallpaper-cache" 2>/dev/null) | args=''${FWD_ARGS[*]}"
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
with open(os.environ['JSON_FILE'], 'w') as f:
    json.dump(colors, f)
PYEOF
  fi
  write_cache "''${FWD_ARGS[@]}"
  eval "$RELOAD_HOOK"
else
  echo "switchwall.sh: original not found at $ORIGINAL" >&2
  exit 1
fi
WRAPPER
      sed -i "s|__STDCXX_LIB__|$STDCXX_LIB|g" "$II_DIR/scripts/colors/switchwall.sh" 2>/dev/null || true
      chmod +x "$II_DIR/scripts/colors/switchwall.sh" 2>/dev/null || true

      # Create Python virtual environment for color generation
      VENV_DIR="$HOME/.local/state/quickshell/.venv"
      if [ ! -f "$VENV_DIR/bin/activate" ]; then
        python3 -m venv --prompt .venv "$VENV_DIR" 2>/dev/null || true
      fi
      # Install/update Python packages (best-effort, needs network)
      if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate" 2>/dev/null || true
        "$VENV_DIR/bin/pip" install -q "materialyoucolor==2.0.10" pillow numpy 2>/dev/null || \
        "$VENV_DIR/bin/pip" install -q --break-system-packages "materialyoucolor==2.0.10" pillow numpy 2>/dev/null || true
        # opencv is needed for --type auto (scheme detection from image)
        "$VENV_DIR/bin/pip" install -q opencv-python-headless 2>/dev/null || \
        "$VENV_DIR/bin/pip" install -q --break-system-packages opencv-python-headless 2>/dev/null || true
        deactivate 2>/dev/null || true
      fi

      # Migrate terminal generation props to better contrast defaults.
      # Only update values that still match the old defaults (harmony=0.6, threshold=100, boost=0.35),
      # so user customizations are preserved.
      SHELL_CONFIG_JSON="''${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
      if [ -f "$SHELL_CONFIG_JSON" ]; then
        jq '
          if (.appearance.wallpaperTheming.terminalGenerationProps.harmony // 0) == 0.6 then
            .appearance.wallpaperTheming.terminalGenerationProps.harmony = 0.25
          else . end
          | if (.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // 0) == 100 then
            .appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = 75
          else . end
          | if (.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // 0) == 0.35 then
            .appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = 0.15
          else . end
        ' "$SHELL_CONFIG_JSON" > "$SHELL_CONFIG_JSON.tmp" 2>/dev/null && mv "$SHELL_CONFIG_JSON.tmp" "$SHELL_CONFIG_JSON" 2>/dev/null || true
      fi
    '';
  };
}
