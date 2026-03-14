#!/usr/bin/env bash
set -u

monitors=(
  "ASUSTek COMPUTER INC ASUS VG249"
  "Acer Technologies SB220Q"
  "Panasonic Industry Company 11SP_HTIB"
)
connected_monitors="$(echo "$(hyprctl monitors |sed -n 's/.*description: \([^,]*\).*/\1/p')"
)"

# Loop over each key
for key in "${monitors[@]}"; do
    if ! grep -qi -- "$key" <<< "$connected_monitors"; then
        #if even one monitor is not detected from the list of above monitors say nah
	exit 0 
    fi
done

for index in "${!monitors[@]}"; do
  monitor="${monitors[index]}"
  workspace=$(( 1 + $index ))
  hyprctl --quiet dispatch workspace name:$workspace
  hyprctl --quiet dispatch moveworkspacetomonitor name:"$workspace" desc:$monitor
done
