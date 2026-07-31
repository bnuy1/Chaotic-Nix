-- Autostart configuration
-- Converts exec-once to hl.on("hyprland.start", ...)

hl.on("hyprland.start", function()
    -- Blue light filter
    hl.exec_cmd("hyprsunset")

    -- Quickshell (replaces waybar) - using wrapper for Stylix color integration
    hl.exec_cmd(HOME .. "/.config/quickshell/launch.sh")

    -- Signal desktop on workspace 2
    hl.exec_cmd("[workspace 2 silent] signal-desktop")

    -- Authentication and privilege escalation
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

    -- Monitor workspace assignment script
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/unique-monitor-config.sh")

    -- Wallpaper (using awww-daemon)
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/Wallpaper.sh")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
