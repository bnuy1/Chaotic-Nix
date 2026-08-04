#!/usr/bin/env bash
set -u

# Assign fixed workspaces to the triple-monitor dock layout:
#   workspace 1 -> ASUS, 2 -> Acer, 3 -> Panasonic.
#
# Hyprland 0.55+ uses Lua-based dispatchers, and hl.dsp.workspace.move only
# relocates EXISTING workspaces: at startup workspace 3 doesn't exist yet, so
# the old script errored with "Workspace not found" and left Panasonic on a
# stray workspace (e.g. 4). We therefore create each workspace first (focus
# auto-creates a missing workspace) and then move it to its target monitor.

monitors=(
  "ASUSTek COMPUTER INC ASUS VG249 0x00009A40"
  "Acer Technologies SB220Q 0x203022C0"
  "Panasonic Industry Company 11SP_HTIB"
)

all_connected() {
  local connected
  connected="$(hyprctl monitors -j 2>/dev/null | jq -r '.[].description // empty' 2>/dev/null)"
  for key in "${monitors[@]}"; do
    grep -Fq -- "$key" <<<"$connected" || return 1
  done
  return 0
}

# External monitors can take a moment to appear after hyprland.start; wait for
# them before giving up (startup script, so a short poll is fine).
for attempt in $(seq 1 15); do
  if all_connected; then
    break
  fi
  sleep 1
done

if ! all_connected; then
  echo "unique-monitor-config: triple-monitor setup not detected, no op" >&2
  exit 0
fi

echo -e "Connected monitors:\n$(hyprctl monitors -j 2>/dev/null | jq -r '.[].description // empty')"

# Workspace 1 -> ASUS, 2 -> Acer, 3 -> Panasonic
for index in "${!monitors[@]}"; do
  monitor="${monitors[index]}"
  workspace=$((1 + index))
  echo "dispatching ${monitor} to workspace ${workspace}"
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$workspace\" })" >/dev/null 2>&1 || true
  hyprctl dispatch "hl.dsp.workspace.move({ workspace = $workspace, monitor = 'desc:$monitor' })" >/dev/null 2>&1 || true
done
