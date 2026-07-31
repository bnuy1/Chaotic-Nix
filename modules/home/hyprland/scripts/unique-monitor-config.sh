#!/usr/bin/env bash
set -u

# bnuy's exact 3-monitor setup. Only touches anything when ALL THREE
# monitors are detected by their full description string, so this is a
# no-op on any other machine / monitor layout.
monitors=(
  "ASUSTek COMPUTER INC ASUS VG249 0x00009A40"
  "Acer Technologies SB220Q 0x203022C0"
  "Panasonic Industry Company 11SP_HTIB"
)

connected_monitors="$(hyprctl monitors | sed -n 's/.*description: \([^,]*\).*/\1/p')"

for key in "${monitors[@]}"; do
  if ! grep -Fq -- "$key" <<< "$connected_monitors"; then
    exit 0
  fi
done

# Workspace 1 -> ASUS, 2 -> Acer, 3 -> Panasonic
# Hyprland 0.55+ (Lua config) requires the Lua-call dispatch syntax.
for index in "${!monitors[@]}"; do
  monitor="${monitors[index]}"
  workspace=$((1 + index))
  hyprctl --quiet dispatch "hl.dsp.workspace.move({ workspace = $workspace, monitor = 'desc:$monitor' })"
done
