#!/usr/bin/env python3
"""
Convert base16 color palette to Material Design 3 colors.json format.
Reads HYPRLAND_PALETTE env var (JSON with base00-base0F keys).
Writes colors.json to ~/.local/state/quickshell/user/generated/colors.json
"""

import json
import os
import sys
from pathlib import Path

def hex_to_rgb(hex_color: str) -> tuple:
    """Convert hex color string to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert RGB tuple to hex color string."""
    return f"#{r:02X}{g:02X}{b:02X}"

def mix_colors(color1: str, color2: str, weight: float) -> str:
    """Mix two hex colors with a given weight (0.0 to 1.0)."""
    r1, g1, b1 = hex_to_rgb(color1)
    r2, g2, b2 = hex_to_rgb(color2)
    r = int(r1 * (1 - weight) + r2 * weight)
    g = int(g1 * (1 - weight) + g2 * weight)
    b = int(b1 * (1 - weight) + b2 * weight)
    return f"#{r:02X}{g:02X}{b:02X}"

def generate_m3_colors(base16: dict) -> dict:
    """Generate Material Design 3 colors from base16 palette."""
    # Base16 colors
    bg = base16.get("base00", "#1E1E2E")      # Background
    bg_light = base16.get("base01", "#313244")  # Lighter background
    bg_lighter = base16.get("base02", "#45475A") # Selection background
    bg_lightest = base16.get("base03", "#585B70") # Comments
    fg_dark = base16.get("base04", "#A6ADC8")   # Dark foreground
    fg = base16.get("base05", "#CDD6F4")        # Foreground
    fg_light = base16.get("base06", "#DCE0E8")  # Light foreground
    fg_lightest = base16.get("base07", "#F5F5F5") # Lightest foreground
    
    red = base16.get("base08", "#F38BA8")       # Variables, errors
    orange = base16.get("base09", "#FAB387")    # Integers, constants
    yellow = base16.get("base0A", "#F9E2AF")    # Classes, warnings
    green = base16.get("base0B", "#A6E3A1")     # Strings, success
    cyan = base16.get("base0C", "#94E2D5")      # Regex, special
    blue = base16.get("base0D", "#89B4FA")      # Functions, primary
    purple = base16.get("base0E", "#CBA6F7")    # Keywords, secondary
    brown = base16.get("base0F", "#F5C2E7")     # Deprecated, tertiary
    
    is_dark = True  # Assume dark mode for now, will be determined by background lightness
    
    # Generate M3 color scheme
    m3_colors = {
        # Background
        "background": bg,
        "on_background": fg,
        
        # Surface
        "surface": bg,
        "surface_dim": bg,
        "surface_bright": bg_lighter,
        "surface_container_lowest": mix_colors(bg, "#FFFFFF", 0.05),
        "surface_container_low": mix_colors(bg, "#FFFFFF", 0.1),
        "surface_container": mix_colors(bg, "#FFFFFF", 0.15),
        "surface_container_high": mix_colors(bg, "#FFFFFF", 0.2),
        "surface_container_highest": bg_lighter,
        
        # On Surface
        "on_surface": fg,
        "on_surface_variant": fg_dark,
        
        # Surface Variant
        "surface_variant": bg_lightest,
        "on_surface_variant": fg_dark,
        
        # Inverse
        "inverse_surface": fg,
        "inverse_on_surface": bg,
        
        # Outline
        "outline": bg_lightest,
        "outline_variant": bg_lighter,
        
        # Primary (blue)
        "primary": blue,
        "on_primary": bg,
        "primary_container": mix_colors(blue, bg, 0.3),
        "on_primary_container": fg,
        "inverse_primary": mix_colors(blue, bg, 0.5),
        
        # Secondary (purple)
        "secondary": purple,
        "on_secondary": bg,
        "secondary_container": mix_colors(purple, bg, 0.3),
        "on_secondary_container": fg,
        
        # Tertiary (brown/pink)
        "tertiary": brown,
        "on_tertiary": bg,
        "tertiary_container": mix_colors(brown, bg, 0.3),
        "on_tertiary_container": fg,
        
        # Error (red)
        "error": red,
        "on_error": bg,
        "error_container": mix_colors(red, bg, 0.3),
        "on_error_container": fg,
        
        # Success (green)
        "success": green,
        "on_success": bg,
        "success_container": mix_colors(green, bg, 0.3),
        "on_success_container": fg,
        
        # Shadow and Scrim
        "shadow": "#000000",
        "scrim": "#000000",
        
        # Terminal colors (term0-term15)
        "term0": bg,          # Black
        "term1": red,         # Red
        "term2": green,       # Green
        "term3": yellow,      # Yellow
        "term4": blue,        # Blue
        "term5": purple,      # Magenta
        "term6": cyan,        # Cyan
        "term7": fg,          # White
        "term8": bg_light,    # Bright Black
        "term9": mix_colors(red, "#FFFFFF", 0.2),    # Bright Red
        "term10": mix_colors(green, "#FFFFFF", 0.2),  # Bright Green
        "term11": mix_colors(yellow, "#FFFFFF", 0.2), # Bright Yellow
        "term12": mix_colors(blue, "#FFFFFF", 0.2),   # Bright Blue
        "term13": mix_colors(purple, "#FFFFFF", 0.2), # Bright Magenta
        "term14": mix_colors(cyan, "#FFFFFF", 0.2),   # Bright Cyan
        "term15": fg_light,   # Bright White
    }
    
    return m3_colors

def main():
    # Read HYPRLAND_PALETTE env var
    palette_json = os.environ.get("HYPRLAND_PALETTE", "{}")
    try:
        base16 = json.loads(palette_json)
    except json.JSONDecodeError:
        print("Error: Invalid HYPRLAND_PALETTE JSON", file=sys.stderr)
        sys.exit(1)
    
    # Generate M3 colors
    m3_colors = generate_m3_colors(base16)
    
    # Determine output path
    state_dir = Path.home() / ".local" / "state" / "quickshell" / "user" / "generated"
    state_dir.mkdir(parents=True, exist_ok=True)
    output_path = state_dir / "colors.json"
    
    # Write colors.json
    with open(output_path, 'w') as f:
        json.dump(m3_colors, f, indent=2)
    
    print(f"Generated colors.json at {output_path}")

if __name__ == "__main__":
    main()
