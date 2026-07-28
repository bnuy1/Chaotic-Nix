#!/usr/bin/env bash
# Quickshell launcher with Stylix color integration
# Generates colors.json from HYPRLAND_PALETTE before launching Quickshell

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate colors.json from HYPRLAND_PALETTE if it exists
if [ -n "$HYPRLAND_PALETTE" ]; then
    # Use python3 from nixpkgs if available
    PYTHON=$(command -v python3 || echo "python3")
    "$PYTHON" "$SCRIPT_DIR/base16-to-m3.py" 2>/dev/null || true
fi

# Launch Quickshell with ii config
exec qs -c ii "$@"
