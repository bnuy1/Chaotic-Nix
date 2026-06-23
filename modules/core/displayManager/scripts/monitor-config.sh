#!/usr/bin/env bash
set -u

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

  for conn in "${connectors[@]}"; do
    if ! grep -qi "^$conn connected" <<< "$connected"; then
      return 1
    fi
  done

  xrandr --output HDMI-A-1 --primary --mode 1920x1080 --rate 144 --pos 0x0 \
         --output DP-3       --mode 1920x1080 --rate 60  --pos -1920x0 \
         --output DP-1       --mode 1920x1080 --rate 60  --pos 0x-1080
  layout_configured=true
}

# ── Wayland (kscreen-doctor) ──────────────────────────────────────────
configure_wayland() {
  if ! command -v kscreen-doctor &>/dev/null; then
    return 1
  fi

  for conn in "${connectors[@]}"; do
    if ! kscreen-doctor -o 2>/dev/null | grep -qi "$conn"; then
      return 1
    fi
  done

  kscreen-doctor output.HDMI-A-1.position.0x0 output.HDMI-A-1.enable \
                  output.DP-3.position.-1920x0 output.DP-3.enable \
                  output.DP-1.position.0x-1080 output.DP-1.enable
  layout_configured=true
}

# ── Detect display server ─────────────────────────────────────────────
if [ -n "${DISPLAY:-}" ] || command -v xrandr &>/dev/null; then
  configure_xrandr
fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ "$layout_configured" = false ]; then
  configure_wayland
fi
