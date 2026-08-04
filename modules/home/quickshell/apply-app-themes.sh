#!/usr/bin/env bash
# Generate app themes from the current quickshell MD3 palette (colors.json).
# colors.json is produced by the color pipeline (switchwall.sh) from either
# matugen (MD3 from wallpaper) or the Stylix bridge (base16 mapped to MD3).
# Call this after every color sync so fuzzel / GTK / foot / fish / wlogout
# always match the palette selected in quickshell.

set -u

COLORS_JSON="${1:-$HOME/.local/state/quickshell/user/generated/colors.json}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

# Resolve a color by trying both the MD3 camelCase and snake_case key forms
# (matugen emits camelCase; the Stylix bridge file uses snake_case).
snake() { printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\L\2/g'; }
get() {
  local k="$1" s
  s="$(snake "$k")"
  jq -r ".[\"$k\"] // .[\"$s\"] // empty" "$COLORS_JSON" 2>/dev/null
}

# Neutral dark MD3 fallback palette used for any key that is missing
# (fresh install / headless / Stylix bridge has no terminal keys). The real
# palette replaces these on the first quickshell color sync.
background="#111318"
on_background="#E2E2E9"
on_surface="#E2E2E9"
primary="#ACC7FF"
on_primary="#0E2F60"
secondary="#BFC6DB"
tertiary="#DDBDE0"
error="#FFB4AB"
error_container="#93000A"
on_error_container="#FFDAD6"
secondary_container="#33435F"
on_secondary_container="#D6E3FF"
surface_variant="#44474F"
on_surface_variant="#C4C6D0"
surface_container="#1E2025"
surface_container_low="#191B20"
surface_container_high="#282A2F"
surface_container_highest="#33353B"
surface_container_lowest="#0C0E13"
outline="#8E9099"
outline_variant="#44474F"
scrim="#000000"
inverse_surface="#E2E2E9"
inverse_on_surface="#2F3036"
inverse_primary="#5E99FF"
term0="#111318"
term1="#FFB4AB"
term2="#BFE4C2"
term3="#E7D99F"
term4="#ACC7FF"
term5="#D0BCFF"
term6="#82CFD0"
term7="#E2E2E9"
term8="#44474F"
term9="#FFB4AB"
term10="#BFE4C2"
term11="#E7D99F"
term12="#ACC7FF"
term13="#D0BCFF"
term14="#82CFD0"
term15="#F6EFF5"

# Override with real palette values when colors.json exists.
if [ -f "$COLORS_JSON" ]; then
  background="$(get term0)"; background="${background:-#111318}"
  on_background="$(get onBackground)"; on_background="${on_background:-#E2E2E9}"
  on_surface="$(get onSurface)"; on_surface="${on_surface:-#E2E2E9}"
  primary="$(get primary)"; primary="${primary:-#ACC7FF}"
  on_primary="$(get onPrimary)"; on_primary="${on_primary:-#0E2F60}"
  secondary="$(get secondary)"; secondary="${secondary:-#BFC6DB}"
  tertiary="$(get tertiary)"; tertiary="${tertiary:-#DDBDE0}"
  error="$(get error)"; error="${error:-#FFB4AB}"
  error_container="$(get errorContainer)"; error_container="${error_container:-#93000A}"
  on_error_container="$(get onErrorContainer)"; on_error_container="${on_error_container:-#FFDAD6}"
  secondary_container="$(get secondaryContainer)"; secondary_container="${secondary_container:-#33435F}"
  on_secondary_container="$(get onSecondaryContainer)"; on_secondary_container="${on_secondary_container:-#D6E3FF}"
  surface_variant="$(get surfaceVariant)"; surface_variant="${surface_variant:-#44474F}"
  on_surface_variant="$(get onSurfaceVariant)"; on_surface_variant="${on_surface_variant:-#C4C6D0}"
  surface_container="$(get surfaceContainer)"; surface_container="${surface_container:-#1E2025}"
  surface_container_low="$(get surfaceContainerLow)"; surface_container_low="${surface_container_low:-#191B20}"
  surface_container_high="$(get surfaceContainerHigh)"; surface_container_high="${surface_container_high:-#282A2F}"
  surface_container_highest="$(get surfaceContainerHighest)"; surface_container_highest="${surface_container_highest:-#33353B}"
  surface_container_lowest="$(get surfaceContainerLowest)"; surface_container_lowest="${surface_container_lowest:-#0C0E13}"
  outline="$(get outline)"; outline="${outline:-#8E9099}"
  outline_variant="$(get outlineVariant)"; outline_variant="${outline_variant:-#44474F}"
  scrim="$(get scrim)"; scrim="${scrim:-#000000}"
  inverse_surface="$(get inverseSurface)"; inverse_surface="${inverse_surface:-#E2E2E9}"
  inverse_on_surface="$(get inverseOnSurface)"; inverse_on_surface="${inverse_on_surface:-#2F3036}"
  inverse_primary="$(get inversePrimary)"; inverse_primary="${inverse_primary:-#5E99FF}"
  term0="$(get term0)"; term0="${term0:-#111318}"
  term1="$(get term1)"; term1="${term1:-#FFB4AB}"
  term2="$(get term2)"; term2="${term2:-#BFE4C2}"
  term3="$(get term3)"; term3="${term3:-#E7D99F}"
  term4="$(get term4)"; term4="${term4:-#ACC7FF}"
  term5="$(get term5)"; term5="${term5:-#D0BCFF}"
  term6="$(get term6)"; term6="${term6:-#82CFD0}"
  term7="$(get term7)"; term7="${term7:-#E2E2E9}"
  term8="$(get term8)"; term8="${term8:-#44474F}"
  term9="$(get term9)"; term9="${term9:-#FFB4AB}"
  term10="$(get term10)"; term10="${term10:-#BFE4C2}"
  term11="$(get term11)"; term11="${term11:-#E7D99F}"
  term12="$(get term12)"; term12="${term12:-#ACC7FF}"
  term13="$(get term13)"; term13="${term13:-#D0BCFF}"
  term14="$(get term14)"; term14="${term14:-#82CFD0}"
  term15="$(get term15)"; term15="${term15:-#F6EFF5}"
fi

# ---- fuzzel ---------------------------------------------------------------
mkdir -p "$CFG/fuzzel"
rm -f "$CFG/fuzzel/fuzzel_theme.ini"
cat > "$CFG/fuzzel/fuzzel_theme.ini" <<EOF
[colors]
background=${background}ff
text=${on_background}ff
selection=${surface_variant}ff
selection-text=${on_surface_variant}ff
border=${surface_variant}dd
match=${primary}ff
selection-match=${primary}ff
EOF

# ---- GTK ------------------------------------------------------------------
for gtkdir in gtk-3.0 gtk-4.0; do
  mkdir -p "$CFG/$gtkdir"
  rm -f "$CFG/$gtkdir/gtk.css"
  cat > "$CFG/$gtkdir/gtk.css" <<EOF
/* MD3 colors generated by apply-app-themes.sh (quickshell palette) */

/* Accents */
@define-color accent_color ${primary};
@define-color accent_fg_color ${on_primary};
@define-color accent_bg_color ${primary};
@define-color destructive_bg_color ${error_container};
@define-color destructive_fg_color ${on_error_container};
@define-color destructive_color ${error};
@define-color success_bg_color #374B3E;
@define-color success_fg_color #D1E9D6;
@define-color success_color #B5CCBA;
/* Base surfaces */
@define-color window_bg_color ${background};
@define-color window_fg_color ${on_background};
@define-color headerbar_bg_color ${surface_container};
@define-color headerbar_backdrop_color ${surface_container};
@define-color headerbar_fg_color ${on_surface};
@define-color card_bg_color ${surface_container};
@define-color card_fg_color ${on_surface};
@define-color sidebar_bg_color ${surface_container};
@define-color sidebar_fg_color ${on_surface};
@define-color secondary_sidebar_bg_color ${surface_container_low};
@define-color secondary_sidebar_fg_color ${on_surface};
@define-color sidebar_border_color @sidebar_bg_color;
@define-color sidebar_backdrop_color @sidebar_bg_color;
@define-color view_bg_color ${surface_container_lowest};
@define-color view_fg_color ${on_surface};
@define-color overview_bg_color ${surface_container_lowest};
@define-color overview_fg_color ${on_surface};
/* Popups */
@define-color popover_bg_color ${surface_container_highest};
@define-color popover_fg_color ${on_surface};
@define-color dialog_bg_color ${surface_container_high};
@define-color dialog_fg_color ${on_surface};
@define-color thumbnail_bg_color ${surface_container_high};
@define-color thumbnail_fg_color ${on_surface};

/* Material */
@define-color inverse_on_surface ${inverse_on_surface};
@define-color inverse_primary ${inverse_primary};
@define-color inverse_surface ${inverse_surface};
@define-color surface_container_highest ${surface_container_highest};
@define-color surface_container_high ${surface_container_high};
@define-color on_surface_variant ${on_surface_variant};
@define-color surface_variant ${surface_variant};
@define-color outline ${outline};

/* Legacy GTK3 names: GTK3's fallback theme ignores the modern
 * window_bg_color/headerbar_bg_color/... names above, so map them here too
 * (otherwise GTK3 apps like GNOME MultiWriter stay unthemed). */
@define-color theme_bg_color ${background};
@define-color theme_fg_color ${on_background};
@define-color theme_base_color ${surface_container_lowest};
@define-color theme_text_color ${on_surface};
@define-color theme_selected_bg_color ${primary};
@define-color theme_selected_fg_color ${on_primary};
@define-color theme_unfocused_bg_color ${background};
@define-color theme_unfocused_fg_color ${on_background};
@define-color theme_unfocused_base_color ${surface_container_lowest};
@define-color theme_unfocused_text_color ${on_surface};
@define-color theme_unfocused_selected_bg_color ${primary};
@define-color theme_unfocused_selected_fg_color ${on_primary};
@define-color borders ${outline_variant};
@define-color unfocused_borders ${outline_variant};

* {
  caret-color: @accent_color;
}

window {
  background: @window_bg_color;
}

.text-button {
  border-radius: 999px;
}

headerbar button {
  border-radius: 999px;
}

switch {
  background: @secondary_sidebar_bg_color;
  border: @outline 2px solid;
  padding: 0;
}

switch:checked {
  background: @accent_color;
  border-color: @accent_color;
}

switch slider {
  background: @outline;
  margin: 3px;
  min-width: 0;
  min-height: 0;
}

switch:checked slider {
  background: @accent_fg_color;
  margin: 0px;
}

toast {
  border-radius: 999px;
  padding: 6px 6px 6px 10px;
  background-color: @inverse_surface;
  color: @inverse_on_surface;
}

toast button {
  background-color: transparent;
  color: @inverse_primary;
}

popover contents,
popover arrow {
  background: @secondary_sidebar_bg_color;
}

modelbutton:hover {
  background-color: @popover_fg_color;
}

tooltip {
  background-color: @inverse_surface;
  color: @inverse_on_surface;
  font-size: 11px;
  padding: 5px 9px;
}
EOF
done

# ---- foot -----------------------------------------------------------------
# foot wants bare RRGGBB hex (no '#') and >= 1.26 prefers [colors-dark].
mkdir -p "$CFG/foot"
rm -f "$CFG/foot/colors.ini"
cat > "$CFG/foot/colors.ini" <<EOF
[colors-dark]
alpha=1.0
foreground=${on_background#\#}
background=${background#\#}
regular0=${term0#\#}
regular1=${term1#\#}
regular2=${term2#\#}
regular3=${term3#\#}
regular4=${term4#\#}
regular5=${term5#\#}
regular6=${term6#\#}
regular7=${term7#\#}
bright0=${term8#\#}
bright1=${term9#\#}
bright2=${term10#\#}
bright3=${term11#\#}
bright4=${term12#\#}
bright5=${term13#\#}
bright6=${term14#\#}
bright7=${term15#\#}
EOF

# ---- fish -----------------------------------------------------------------
# Wallpaper-driven fish colors referenced by ANSI slot NAME (red/green/...
# map to terminal palette slots 1..8, which the generator rotates with the
# wallpaper accent and palette mode). Named slots keep already-open fish
# shells live: the colors resolve against the running terminal's palette,
# so when apply-app-themes.sh reloads kitty the prompt/syntax update
# without re-sourcing fish. (Bare numeric indexes like "1" are rejected by
# set_color, and hex would be frozen in running shells.)
mkdir -p "$CFG/fish/conf.d"
rm -f "$CFG/fish/conf.d/99-quickshell-colors.fish"
cat > "$CFG/fish/conf.d/99-quickshell-colors.fish" <<EOF
# Generated by apply-app-themes.sh (quickshell palette) - wallpaper-driven.
set -g fish_color_command red
set -g fish_color_escape red
set -g fish_color_cwd red
set -g fish_color_error "$error"
set -g fish_color_quote magenta
set -g fish_color_operator green
set -g fish_color_redirection yellow
set -g fish_color_option green
set -g fish_color_normal normal
set -g fish_color_param normal
set -g fish_color_end brblack
set -g fish_color_comment brblack
set -g fish_color_autosuggestion brblack
set -g fish_color_selection normal --background "$surface_variant"
set -g fish_color_search_match "$on_primary" --background "$primary"
set -g fish_color_user blue
set -g fish_color_host cyan
set -g fish_color_valid_path --underline
EOF

# ---- wlogout --------------------------------------------------------------
mkdir -p "$CFG/wlogout"
rm -f "$CFG/wlogout/style.css"
cat > "$CFG/wlogout/style.css" <<EOF
* {
	all: unset;
	background-image: none;
	transition: 400ms cubic-bezier(0.05, 0.7, 0.1, 1);
}

window {
	background: ${scrim}b3;
}

button {
	font-family: 'Material Symbols Outlined';
	font-size: 10rem;
	background-color: ${surface_container}80;
	color: ${on_surface};
	margin: 2rem;
	border-radius: 2rem;
	padding: 3rem;
}

button:focus,
button:active,
button:hover {
	background-color: ${surface_container_high}b3;
	color: ${primary};
	border-radius: 4rem;
}
EOF

# ---- vesktop (Discord) -----------------------------------------------------
# Vencord theme consumed by Vesktop; enable it in Vesktop Settings -> Themes.
mkdir -p "$CFG/vesktop/themes"
cat > "$CFG/vesktop/themes/quickshell-m3.theme.css" <<EOF
/**
 * quickshell-m3.theme.css - Material You (quickshell palette)
 * Generated by apply-app-themes.sh. Enable in Vesktop: Settings -> Themes.
 */
:root {
  --background-primary: ${surface_container};
  --background-secondary: ${surface_container_low};
  --background-secondary-alt: ${surface_container_low};
  --background-tertiary: ${surface_container_lowest};
  --background-floating: ${surface_container_high};
  --background-modifier-hover: ${surface_variant}1f;
  --background-modifier-active: ${surface_variant}33;
  --background-modifier-selected: ${surface_variant}4d;
  --channeltextarea-background: ${surface_container_low};
  --activity-card-background: ${surface_container};
  --input-background: ${surface_container_low};
  --modal-background: ${surface_container};
  --modal-footer-background: ${surface_container_high};
  --scrollbar-thin-thumb: ${surface_variant};
  --scrollbar-auto-thumb: ${surface_variant};
  --text-normal: ${on_surface};
  --text-muted: ${on_surface_variant};
  --text-link: ${primary};
  --header-primary: ${on_background};
  --header-secondary: ${on_surface_variant};
  --brand-experiment: ${primary};
  --brand-experiment-560: ${primary};
  --interactive-normal: ${on_surface_variant};
  --interactive-hover: ${on_surface};
  --interactive-active: ${on_surface};
  --interactive-muted: ${outline};
  --deprecated-text-input-bg: ${surface_container_lowest};
  --deprecated-text-input-border: ${outline_variant};
  --deprecated-card-bg: ${surface_container_low};
  --deprecated-card-editable-bg: ${surface_container_low};
  --deprecated-store-bg: ${surface_container_lowest};
  --home-background: ${background};
  --focus-ring: ${primary};
}
EOF

# ---- spicetify (Spotify) ---------------------------------------------------
# Theme files for spicetify-cli. The running client recolors itself live: the
# recolor extension polls colors.css and swaps the stylesheet link whenever
# `spicetify -n refresh` regenerates it below. Every spicetify palette slot is
# mapped from MD3 so nothing falls back to Spotify's default green.
mkdir -p "$CFG/spicetify/Themes/quickshell-m3"
cat > "$CFG/spicetify/Themes/quickshell-m3/color.ini" <<EOF
[Base]
accent = ${primary#\#}
accent-active = ${primary#\#}
accent-inactive = ${outline#\#}
button = ${primary#\#}
button-active = ${inverse_primary#\#}
button-disabled = ${outline#\#}
tab-active = ${surface_container_highest#\#}
notification = ${inverse_surface#\#}
notification-error = ${error#\#}
misc = ${outline#\#}
subtext = ${on_surface_variant#\#}
text = ${on_surface#\#}
sidebar = ${surface_container#\#}
main = ${background#\#}
player = ${surface_container#\#}
card = ${surface_container_high#\#}
shadow = ${scrim#\#}
selected-row = ${surface_container_highest#\#}
highlight = ${surface_container_high#\#}
highlight-elevated = ${surface_container_highest#\#}
EOF
cat > "$CFG/spicetify/Themes/quickshell-m3/user.css" <<EOF
/* quickshell-m3 - Material You (quickshell palette)
 * Generated by apply-app-themes.sh.
 * Snippets: rotatingCoverart, pointer (spicetify-nix). */
@keyframes rotating {from {transform: rotate(0deg);}to {transform: rotate(360deg);}}.cover-art, .main-nowPlayingView-coverArtContainer::after, .main-nowPlayingView-coverArtContainer::before {animation: rotating 10s linear infinite;border-radius: 50%;}.cover-art {clip-path: circle(50% at 50% 50%);} .main-nowPlayingBar-left button {background: transparent;} .main-nowPlayingView-coverArt {box-shadow:none; filter: drop-shadow(0 9px 9px rgba(0,0,0,.271));}
button, .show-followButton-button, .main-dropDown-dropDown, .x-toggle-wrapper, .main-playlistEditDetailsModal-closeBtn, .main-trackList-rowPlayPauseButton, .main-rootlist-rootlistItemLink:link, .main-rootlist-rootlistItemLink:visited, .x-sortBox-sortDropdown, .main-contextMenu-menuItemButton, .main-trackList-column, .main-moreButton-button, .x-downloadButton-button, .main-playButton-PlayButton, .main-coverSlotExpandedCollapseButton-chevron, .main-coverSlotCollapsed-chevron, .control-button:focus, .control-button:hover, .main-repeatButton-button, .main-skipForwardButton-button, .main-playPauseButton-button, .main-skipBackButton-button, .main-shuffleButton-button, .main-addButton-button, .progress-bar__slider, .playback-bar, .main-editImageButton-image, .X1lXSiVj0pzhQCUo_72A, .main-card-card, .main-trackList-trackListRow, .Dropdown-control { cursor: pointer !important; }
EOF

# Regenerate the app's colors.css from the palette so the running Spotify
# client recolors immediately (the recolor extension detects the change).
# No-op outside a graphical session (spicetify-cli not on PATH at activation).
if command -v spicetify >/dev/null 2>&1; then
  spicetify -n refresh >/dev/null 2>&1 || true
fi

# ---- live reload -----------------------------------------------------------
# Reload running kitty instances so the new palette (and the ANSI-indexed
# fish colors that resolve against it) apply immediately in open terminals.
# kitty reloads its config on SIGUSR1 (docs: "kill -SIGUSR1 $KITTY_PID").
# On NixOS the kitty binary is wrapped, so the process comm is
# `.kitty-wrapped`; match both forms.
pkill -USR1 -x .kitty-wrapped 2>/dev/null || true
pkill -USR1 -x kitty 2>/dev/null || true

exit 0
