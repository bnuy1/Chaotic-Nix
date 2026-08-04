-- App launchers (seeded once by Nix; preserved across builds)
-- Uses launch_first_available.sh: the first installed app wins
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'kitty' 'foot' 'alacritty' 'wezterm'"
fileManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'dolphin' 'nautilus' 'thunar' 'pcmanfm-qt'"
browser = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'librewolf' 'firefox' 'google-chrome-stable' 'chromium'"
codeEditor = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'code' 'codium' 'cursor' 'zed'"
officeSoftware = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'libreoffice' 'onlyoffice-desktopeditors'"
textEditor = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'gnome-text-editor' 'gedit' 'kate'"
volumeMixer = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'pavucontrol' 'pavucontrol-qt'"
settingsApp = "XDG_CURRENT_DESKTOP=gnome ~/.config/hypr/hyprland/scripts/launch_first_available.sh 'qs -p ~/.config/quickshell/$qsConfig/settings.qml' 'gnome-control-center' 'systemsettings'"
taskManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'gnome-system-monitor' 'io.missioncenter.MissionCenter' 'btop'"

workspaceGroupSize = 10
