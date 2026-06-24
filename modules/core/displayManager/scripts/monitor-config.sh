#!/usr/bin/env bash
set -u -o pipefail

logger -t monitor-config "starting monitor configuration"

# Known monitors for bnuy's specific 3-monitor desktop setup.
# Only activates when all three are detected — otherwise no-op.
monitors=(
  "ASUSTek COMPUTER INC ASUS VG249"
  "Acer Technologies SB220Q"
  "Panasonic Industry Company 11SP_HTIB"
)

connectors=("HDMI-A-1" "DP-3" "DP-1")
layout_configured=false

# ── X11 (xrandr) ──────────────────────────────────────────────────────
configure_xrandr() {
  local connected
  connected="$(xrandr --query 2>/dev/null)" || return 1

  local all_found=true
  for conn in "${connectors[@]}"; do
    if ! grep -qi "$conn connected" <<< "$connected"; then
      logger -t monitor-config "connector $conn not found"
      all_found=false
    fi
  done

  if [ "$all_found" = false ]; then
    logger -t monitor-config "not all connectors found, skipping xrandr"
    return 1
  fi

  logger -t monitor-config "applying xrandr layout"

  # Reset all outputs first to avoid mode conflicts
  xrandr --output HDMI-A-1 --off \
         --output DP-3 --off \
         --output DP-1 --off

  sleep 0.5

  # Configure with ASUS (HDMI-A-1) as primary
  xrandr --output HDMI-A-1 --primary --mode 1920x1080 --rate 144 --pos 0x0 \
         --output DP-3       --mode 1920x1080 --rate 60  --pos -1920x0 \
         --output DP-1       --mode 1920x1080 --rate 60  --pos 0x-1080 2>&1 | logger -t monitor-config

  layout_configured=true
  logger -t monitor-config "xrandr layout applied successfully"
}

# ── Wayland (kscreen-doctor) ──────────────────────────────────────────
configure_wayland() {
  if ! command -v kscreen-doctor &>/dev/null; then
    logger -t monitor-config "kscreen-doctor not found"
    return 1
  fi

  local all_found=true
  for conn in "${connectors[@]}"; do
    if ! kscreen-doctor -o 2>/dev/null | grep -qi "$conn"; then
      logger -t monitor-config "kscreen connector $conn not found"
      all_found=false
    fi
  done

  if [ "$all_found" = false ]; then
    logger -t monitor-config "not all kscreen connectors found"
    return 1
  fi

  logger -t monitor-config "applying kscreen-doctor layout"
  kscreen-doctor output.HDMI-A-1.position.0x0 output.HDMI-A-1.enable \
                  output.DP-3.position.-1920x0 output.DP-3.enable \
                  output.DP-1.position.0x-1080 output.DP-1.enable 2>&1 | logger -t monitor-config
  layout_configured=true
  logger -t monitor-config "kscreen layout applied successfully"
}

# ── Detect display server ─────────────────────────────────────────────
sleep 0.5

if [ -n "${DISPLAY:-}" ] || command -v xrandr &>/dev/null; then
  logger -t monitor-config "detected X11, trying xrandr"
  configure_xrandr
fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ "$layout_configured" = false ]; then
  logger -t monitor-config "detected Wayland, trying kscreen-doctor"
  configure_wayland
fi

if [ "$layout_configured" = false ]; then
  logger -t monitor-config "no layout configured — monitors may not match known setup"
fi
