#!/usr/bin/env bash
# Generate terminal themes (kitty + ANSI escape sequences) from colors.json.
#
# Unlike the end-4 version, this reads the quickshell MD3 palette directly
# (colors.json) instead of material_colors.scss, so it works on both full
# regenerations and cached palette syncs (where the .scss may not exist).
# colors.json is produced by either matugen (MD3 from wallpaper) or the
# Stylix bridge, so the terminal always matches the selected palette.

set -u

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
GEN_DIR="$STATE_DIR/user/generated"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLORS_JSON="$GEN_DIR/colors.json"

term_alpha=100 # Set this to < 100 to make all your terminals transparent

# Resolve a color by trying both the MD3 camelCase and snake_case key forms
# (matugen emits camelCase; the Stylix bridge file uses snake_case).
snake() { printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\L\2/g'; }
# fall back to an MD3-derived color when a termN key is absent
# keys are written in snake_case so they resolve against the bridge file too
get() {
  local k="$1" s fallback
  s="$(snake "$k")"
  case "$k" in
    term0)  fallback="background" ;;
    term1)  fallback="error" ;;
    term2)  fallback="success" ;;
    term3)  fallback="tertiary" ;;
    term4)  fallback="primary" ;;
    term5)  fallback="secondary" ;;
    term6)  fallback="tertiary" ;;
    term7)  fallback="on_background" ;;
    term8)  fallback="outline" ;;
    term9)  fallback="error_container" ;;
    term10) fallback="success_container" ;;
    term11) fallback="tertiary_container" ;;
    term12) fallback="primary_container" ;;
    term13) fallback="secondary_container" ;;
    term14) fallback="tertiary_container" ;;
    term15) fallback="on_surface" ;;
    *)      fallback="" ;;
  esac
  if [ -n "$fallback" ]; then
    jq -r ".[\"$k\"] // .[\"$s\"] // .[\"$fallback\"] // empty" "$COLORS_JSON" 2>/dev/null
  else
    jq -r ".[\"$k\"] // .[\"$s\"] // empty" "$COLORS_JSON" 2>/dev/null
  fi
}

# Substitute every '$name #' placeholder in a template with its palette value.
# write atomically via temp file then rename
# kitty reloads its config on change so a half-written file crashes the terminal
# a racing reload sees either the old or the new complete file
substitute_template() {
  local tpl="$1" out="$2" name val tmp
  [ -f "$tpl" ] || return 0
  mkdir -p "$(dirname "$out")"
  tmp="$out.tmp.$$"
  cp "$tpl" "$tmp"
  chmod u+w "$tmp" 2>/dev/null || true
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    val="$(get "$name")"
    [ -z "$val" ] && continue
    # The template already carries the '#' marker before the token
    # (#$term0 #), so strip the leading '#' from the palette value; the
    # pattern also consumes the trailing ' #' after the token.
    sed -i "s|\$$name #|${val#\#}|g" "$tmp"
  done < <(grep -oE '\$[A-Za-z0-9_]+' "$tpl" | sed 's/^\$//' | sort -u)
  mv -f "$tmp" "$out" 2>/dev/null || true
  rm -f "$tmp" 2>/dev/null || true
  chmod u+w "$out" 2>/dev/null || true
}

apply_kitty() {
  [ -f "$COLORS_JSON" ] || return 0
  substitute_template "$SCRIPT_DIR/terminal/kitty-theme.conf" "$GEN_DIR/terminal/kitty-theme.conf"
  # Reload running kitty instances so the new palette applies immediately.
  # On NixOS the kitty binary is wrapped, so match both forms.
  if pgrep -f kitty >/dev/null 2>&1; then
    kill -SIGUSR1 $(pidof kitty) 2>/dev/null || true
  fi
}

apply_anyterm() {
  [ -f "$COLORS_JSON" ] || return 0
  substitute_template "$SCRIPT_DIR/terminal/sequences.txt" "$GEN_DIR/terminal/sequences.txt"
  sed -i "s/\$alpha/$term_alpha/g" "$GEN_DIR/terminal/sequences.txt" 2>/dev/null || true
  for file in /dev/pts/[0-9]*; do
    {
      cat "$GEN_DIR/terminal/sequences.txt" >"$file"
    } & disown || true
  done
}

apply_term() {
  apply_anyterm &
  apply_kitty &
}

# Write Hyprland border colors (loaded by the entrypoint's custom.colors require)
apply_hypr() {
  [ -f "$COLORS_JSON" ] || return 0
  local active inactive bg
  active="$(get primary)";          active="${active:-#ACC7FF}"
  inactive="$(get outlineVariant)"; inactive="${inactive:-#44474F}"
  bg="$(get term0)";                bg="${bg:-#111318}"
  mkdir -p "$HOME/.config/hypr/custom"
  cat > "$HOME/.config/hypr/custom/colors.lua" <<EOF
-- MD3 colors written by applycolor.sh (quickshell palette)
hl.config({
	general = {
		col = {
			active_border = "rgba(${active#\#}FF)",
			inactive_border = "rgba(${inactive#\#}FF)",
		},
	},
	misc = {
		background_color = "rgba(${bg#\#}FF)",
	},
})
EOF
  # Reload so new border colors apply immediately
  hyprctl reload >/dev/null 2>&1 || true
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal="$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE" 2>/dev/null)"
  if [ "$enable_terminal" = "true" ]; then
    apply_term
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term
fi

# Hyprland border colors always follow the palette (independent of terminal theming)
apply_hypr

# Let the backgrounded anyterm/kitty jobs finish before we exit
wait 2>/dev/null || true

exit 0
