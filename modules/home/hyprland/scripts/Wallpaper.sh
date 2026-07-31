#!/usr/bin/env bash

LOCATION="$HOME/Pictures/Wallpapers"

# Create directory if it doesn't exist
[ ! -d "$LOCATION" ] && mkdir -p "$LOCATION"

# Pick a random wallpaper
#wallpaper=$(find "$LOCATION" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)
wallpaper="/etc/nixos/assets/current-wallpaper.png"

echo "Selected wallpaper: $wallpaper"

# Start awww-daemon if not already running
if ! pgrep "awww-daemon" >/dev/null; then
  awww-daemon &
  sleep 0.5 # give daemon time to start
fi

# Set the wallpaper
awww img "$wallpaper"
