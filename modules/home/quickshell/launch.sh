#!/usr/bin/env bash
# Quickshell launcher
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find and add gsettings schemas to XDG_DATA_DIRS
for profile in "$HOME/.nix-profile" "/etc/profiles/per-user/$USER" "/run/current-system/sw"; do
  resolved="$(readlink -f "$profile" 2>/dev/null || echo "$profile")"
  schema_dir="$resolved/share/gsettings-schemas"
  if [ -d "$schema_dir" ]; then
    for schema in "$schema_dir"/*; do
      if [ -d "$schema" ] && [[ ":$XDG_DATA_DIRS:" != *":$schema:"* ]]; then
        XDG_DATA_DIRS="${XDG_DATA_DIRS:+$XDG_DATA_DIRS:}$schema"
      fi
    done
  fi
done
export XDG_DATA_DIRS

# use the hicolor icon theme so icons load with paths
export QS_ICON_THEME=hicolor

# Python virtual environment for color generation (materialyoucolor, pillow, etc.)
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="$HOME/.local/state/quickshell/.venv"
# do not export LD_LIBRARY_PATH here
# a global one breaks hyprctl
# the venv python entrypoints set their own LD_LIBRARY_PATH

exec qs -c ii "$@"
