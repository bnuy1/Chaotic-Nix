#!/usr/bin/env bash
set -u

# no-op unless all three are detected.
monitors=(
  "ASUSTek COMPUTER INC ASUS VG249 0x00009A40"
  "Acer Technologies SB220Q 0x203022C0"
  "Panasonic Industry Company 11SP_HTIB"
)

connected_monitors="$(hyprctl monitors | sed -n 's/.*description: \([^,]*\).*/\1/p')"

echo -e "Connected monitors :\n $connected_monitors"

for key in "${monitors[@]}"; do
  if ! grep -Fq -- "$key" <<<"$connected_monitors"; then
    echo "no op: exiting"
    exit 0
  fi
done

# Workspace 1 -> ASUS, 2 -> Acer, 3 -> Panasonic
for index in "${!monitors[@]}"; do
  monitor="${monitors[index]}"
  workspace=$((1 + index))
  echo "dispatching ${monitors[index]} to $((1 + $index))"
  hyprctl --quiet dispatch "hl.dsp.workspace.move({ workspace = $workspace, monitor = 'desc:$monitor' })"
done
