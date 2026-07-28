-- Window rules (end4's direct match style)
-- Ported from user's tag-based system to direct matches

----------------------------
---- WINDOW RULES ----------
----------------------------

-- Disable blur for XWayland context menus
hl.window_rule({ match = { class = "^()$", title = "^()$" }, no_blur = true })

-- Browsers
hl.window_rule({ match = { class = "^(firefox|org.mozilla.firefox|firefox-esr|firefox-bin)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(librewolf|librewolf-esr|librewolf-bin)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(google-chrome(-beta|-dev|-unstable)?|chrome-.+-Default)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(chromium)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(microsoft-edge(-stable|-beta|-dev|-unstable))$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(Brave-browser(-beta|-dev|-unstable)?)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(thorium-browser|cachy-browser)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(zen-alpha|zen)$" }, opacity = "1 1" })

-- Terminals
hl.window_rule({ match = { class = "^(Alacritty|kitty|kitty-dropterm)$" }, opacity = "1 1" })

-- Email
hl.window_rule({ match = { class = "^(thunderbird|org.mozilla.Thunderbird)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(eu.betterbird.Betterbird)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(org.gnome.Evolution)$" }, opacity = "1 1" })

-- Code editors
hl.window_rule({ match = { class = "^(codium|codium-url-handler|VSCodium|VSCode|code|code-url-handler)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(jetbrains-.+)$" }, opacity = "1 1" })
hl.window_rule({ match = { class = "^(dev.zed.Zed|antigravity)$" }, opacity = "1 1" })

-- File managers
hl.window_rule({ match = { class = "^(thunar|org.gnome.Nautilus|pcmanfm-qt|app.drey.Warp)$" }, opacity = "1 1" })

-- Settings
hl.window_rule({ match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, float = true, center = true, opacity = "1 1" })
hl.window_rule({ match = { class = "^(nm-applet|nm-connection-editor|blueman-manager)$" }, float = true, center = true, opacity = "1 1" })
hl.window_rule({ match = { class = "^(qt5ct|qt6ct)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(btrfs-assistant|timeshift-gtk)$" }, float = true, center = true })

-- Viewers
hl.window_rule({ match = { class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$" }, float = true, center = true, opacity = "0.82 0.75" })
hl.window_rule({ match = { class = "^(evince)$" }, float = true, center = true, opacity = "0.82 0.75" })
hl.window_rule({ match = { class = "^(eog|org.gnome.Loupe)$" }, float = true, center = true, opacity = "0.82 0.75" })

-- Multimedia
hl.window_rule({ match = { class = "^(mpv|vlc)$" }, no_blur = true, opacity = "1 1" })
hl.window_rule({ match = { class = "^(audacious)$" }, no_blur = true, opacity = "1 1" })

-- Wallpaper
hl.window_rule({ match = { class = "^(waytrogen)$" }, float = true, center = true, opacity = "1 1" })

-- Floating file dialogs
hl.window_rule({ match = { title = "^(Open File)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Select a File)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Choose wallpaper)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Open Folder)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Save As)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Library)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(File Upload)(.*)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(.*)(wants to save)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(.*)(wants to open)$" }, float = true, center = true })

-- XDG Portals (file pickers)
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)" })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-kde)$" }, float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)" })

-- Authentication dialogs
hl.window_rule({ match = { title = "^(Authentication Required)$" }, float = true, center = true })

-- Zoom
hl.window_rule({ match = { class = "^(Zoom|onedriver|onedriver-launcher)$" }, float = true })

-- Calculators
hl.window_rule({ match = { class = "^(org.gnome.Calculator|qalculate-gtk|Qalculate-gtk)$" }, float = true })

-- Ferdium
hl.window_rule({ match = { class = "^(ferdium|Ferdium)$" }, float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.7)" })

-- WhatsApp/ZapZap
hl.window_rule({ match = { class = "^(whatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, size = "(monitor_w*0.6) (monitor_h*0.7)", center = true })

-- Zotero
hl.window_rule({ match = { class = "^(Zotero)$" }, float = true, size = "(monitor_w*0.45) (monitor_h*0.45)" })

-- Picture-in-Picture (end4's PiP rules)
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true })
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, keep_aspect_ratio = true })
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, move = "(monitor_w*0.73) (monitor_h*0.72)" })
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, size = "(monitor_w*0.25) (monitor_h*0.25)" })
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, pin = true })
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, opacity = "0.95 0.75" })

-- Screen sharing notification
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*$" }, float = true, pin = true })
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*$" }, move = "(monitor_w*.5-window_w*.5) (monitor_h-window_h-12)" })

-- Tearing for games
hl.window_rule({ match = { title = ".*\\.exe" }, immediate = true })
hl.window_rule({ match = { title = ".*minecraft.*" }, immediate = true })
hl.window_rule({ match = { class = "^(steam_app).*" }, immediate = true })

-- No shadow for tiled windows
hl.window_rule({ match = { float = false }, no_shadow = true })

-- Idle inhibit for fullscreen
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })

-- Games: no blur, no fullscreen auto
hl.window_rule({ match = { class = "^(gamescope)$" }, no_blur = true, fullscreen = false })
hl.window_rule({ match = { class = "^(steam_app_\\d+)$" }, no_blur = true, fullscreen = false })

-- Thunar progress dialog
hl.window_rule({
    name = "Thunar-Progress-bar",
    match = { class = "^(thunar)$", title = "^(File Operation Progress)$" },
    float = true,
    center = true,
    size = "(monitor_w*0.26) (monitor_h*0.18)",
})

----------------------------
---- WORKSPACE RULES -------
----------------------------

hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })

----------------------------
---- LAYER RULES ----------
----------------------------

-- Global
hl.layer_rule({ match = { namespace = ".*" }, xray = true })

-- No animation for launchers
hl.layer_rule({ match = { namespace = "walker" }, no_anim = true })
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
hl.layer_rule({ match = { namespace = "overview" }, no_anim = true })
hl.layer_rule({ match = { namespace = "anyrun" }, no_anim = true })
hl.layer_rule({ match = { namespace = "indicator.*" }, no_anim = true })
hl.layer_rule({ match = { namespace = "osk" }, no_anim = true })
hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ match = { namespace = "noanim" }, no_anim = true })

-- GTK Layer Shell
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true })
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, ignore_alpha = 0 })

-- Launcher blur
hl.layer_rule({ match = { namespace = "launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "launcher" }, ignore_alpha = 0.5 })

-- Notifications blur
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0.69 })

-- Logout dialog
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })

-- Rofi
hl.layer_rule({ match = { namespace = "rofi" }, blur = true })

-- Quickshell (end4's rules)
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur_popups = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.79 })
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:actionCenter" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:cheatsheet" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%" })
hl.layer_rule({ match = { namespace = "quickshell:lockWindowPusher" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "quickshell:overlay" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:overlay" }, ignore_alpha = 1 })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:polkit" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:popup" }, xray = false })
hl.layer_rule({ match = { namespace = "quickshell:popup" }, ignore_alpha = 1 })
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 1 })
hl.layer_rule({ match = { namespace = "quickshell:reloadPopup" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:regionSelector" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:screenshot" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:session" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:session" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:session" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right" })
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "quickshell:verticalBar" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:osk" }, order = -1 })
hl.layer_rule({ match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top" })
hl.layer_rule({ match = { namespace = "quickshell:wNotificationCenter" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:wOnScreenDisplay" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:wStartMenu" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" }, no_anim = true })

-- Launchers need to be FAST
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true })
