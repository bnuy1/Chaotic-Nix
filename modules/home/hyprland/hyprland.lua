-- Main entry point for Hyprland Lua config
-- Nix-managed: overwritten on every build. Put your own changes in custom/
-- Based on end-4's dots-hyprland hyprland.lua

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")

-- Custom configurations (seeded by Nix once, then preserved) --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/end4-keybinds.lua") then
    require("custom.end4-keybinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end

-- MD3 border colors, written by applycolor.sh (runtime palette) --
if is_file_exists(HOME .. "/.config/hypr/custom/colors.lua") then
    require("custom.colors")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")
