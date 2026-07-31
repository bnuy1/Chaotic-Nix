-- Hyprland Lua Configuration
-- Main entry point: loads all modules
-- Based on end4's structure but simplified (no custom/ override layer)

-- Helper functions
require("lib")

-- Profile system (Nix-generated)
require("profiles")

-- Appearance (monitors, variables, decoration, animations)
require("appearance")

-- Autostart (exec-once commands)
require("autostart")

-- Window/layer/workspace rules
require("rules")

-- Keybinds (profile-aware)
require("binds")
