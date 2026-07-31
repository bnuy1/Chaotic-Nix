#!/usr/bin/env bash
LAUNCHER="fuzzel"
if pgrep -x $LAUNCHER >/dev/null; then
  pkill $LAUNCHER
else
  $LAUNCHER &
fi
