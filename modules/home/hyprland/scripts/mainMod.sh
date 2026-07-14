#!/usr/bin/env bash
LAUNCHER="rofi"
CONFIG="$HOME/.config/rofi/config.rasi"
if pgrep -x $LAUNCHER >/dev/null; then
  pkill $LAUNCHER
else
  # launch in background so Hyprland doesnt block
  $LAUNCHER -show drun -config $CONFIG &
fi
