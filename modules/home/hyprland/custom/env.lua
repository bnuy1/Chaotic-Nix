-- User environment overrides (seeded once by Nix; preserved across builds)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
-- Qt via the GTK3 bridge (overrides end-4's QT_QPA_PLATFORMTHEME=kde)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
-- Quickshell
hl.env("QS_ICON_THEME", "hicolor")
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", os.getenv("HOME") .. "/.local/state/quickshell/.venv")

-- Stylix palette for Quickshell (Nix-generated palette.json)
local palette_file = io.open(HOME .. "/.config/hypr/palette.json", "r")
local palette_json = "{}"
if palette_file then
	palette_json = palette_file:read("*a")
	palette_file:close()
end
hl.env("HYPRLAND_PALETTE", palette_json)
