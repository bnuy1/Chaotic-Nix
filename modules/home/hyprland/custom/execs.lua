-- Autostart (seeded once by Nix; preserved across builds)
-- qs, easyeffects, gnome-keyring, hypridle, cliphist and the cursor are
-- launched by hyprland/execs.lua - do not duplicate them here.

hl.on("hyprland.start", function()
    -- Blue light filter
    hl.exec_cmd("hyprsunset")

    -- Signal desktop on workspace 2
    hl.exec_cmd("[workspace 2 silent] signal-desktop")

    -- Monitor workspace assignment script
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/unique-monitor-config.sh")
end)
