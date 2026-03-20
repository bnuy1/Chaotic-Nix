#!/usr/bin/env bash
set -x

LOCATION="$HOME/Pictures/wallpapers"

# Create directory if it doesn't exist
[ ! -d "$LOCATION" ] && mkdir -p "$LOCATION"

# Pick a random wallpaper
wallpaper=$(find "$LOCATION" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)

echo "Selected wallpaper: $wallpaper"

# Start swww-daemon if not already running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon &
    sleep 0.5   # give daemon time to start
fi

# Set the wallpaper
swww img "$wallpaper"

# Generate colors with pywal
wal -i $wallpaper
