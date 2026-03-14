#!/usr/bin/env bash
		# ~/.local/bin/launcher-toggle.sh

		LAUNCHER="rofi"
		CONFIG="/etc/xdg/rofi/config.rasi"
		if pgrep -x $LAUNCHER > /dev/null; then
  		pkill $LAUNCHER
		else
		# launch in background so Hyprland doesnt block
		   $LAUNCHER -show drun -config $CONFIG &
		fi

