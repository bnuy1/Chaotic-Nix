-- Keybind configuration (user-owned, static)
-- Merged from common binds + QWERTY layout. No profile machinery.
-- Rebuild-safe: lives in custom/, survives nixos-rebuild.

local mainMod = "SUPER"

----------------------------
---- COMMON BINDS ----------
----------------------------

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind(mainMod .. " + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Workspace scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Quickshell globals
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewWorkspacesToggle"), { description = "Shell: Toggle overview" })
hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind("SUPER + Period", hl.dsp.global("quickshell:overviewEmojiToggle"))
hl.bind("SUPER + A", hl.dsp.global("quickshell:sidebarLeftToggle"), { description = "Shell: Toggle left sidebar" })
hl.bind("SUPER + ALT + A", hl.dsp.global("quickshell:sidebarLeftToggleDetach"))
hl.bind("SUPER + B", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + O", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + N", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar" })
hl.bind("SUPER + Slash", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Toggle cheatsheet" })
hl.bind("SUPER + K", hl.dsp.global("quickshell:oskToggle"), { description = "Shell: Toggle on-screen keyboard" })
hl.bind("SUPER + M", hl.dsp.global("quickshell:mediaControlsToggle"), { description = "Shell: Toggle media controls" })
hl.bind("SUPER + G", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle widget overlay" })
hl.bind("CTRL + ALT + Delete", hl.dsp.global("quickshell:sessionToggle"), { description = "Shell: Toggle session menu" })
hl.bind("SUPER + J", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" })

-- Wallpaper controls
hl.bind("CTRL + SUPER + T", hl.dsp.global("quickshell:wallpaperSelectorToggle"), { description = "Shell: Change wallpaper" })
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.global("quickshell:wallpaperSelectorRandom"), { description = "Shell: Random wallpaper" })
hl.bind("CTRL + SUPER + SHIFT + D", hl.dsp.global("quickshell:toggleLightDark"), { description = "Shell: Toggle light/dark mode" })
hl.bind("CTRL + SUPER + SHIFT + C", hl.dsp.global("quickshell:colorSource:cycle"), { description = "Shell: Cycle color source (MD3/Stylix)" })
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("wlogout"), { description = "Session: Logout menu" })
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("killall qs quickshell; qs -c ii &"), { description = "Shell: Restart widgets" })
hl.bind("CTRL + SUPER + P", hl.dsp.global("quickshell:panelFamilyCycle"), { description = "Shell: Cycle panel family" })

-- Screenshot utilities
hl.bind("SUPER + SHIFT + S", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screen snip" })
hl.bind("SUPER + SHIFT + A", hl.dsp.global("quickshell:regionSearch"), { description = "Utilities: Google Lens" })
hl.bind("SUPER + SHIFT + X", hl.dsp.global("quickshell:regionOcr"), { description = "Utilities: Character recognition" })
hl.bind("SUPER + SHIFT + T", hl.dsp.global("quickshell:screenTranslate"), { description = "Utilities: Translate screen content" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick color" })
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:regionRecord"), { locked = true, description = "Utilities: Record region" })

-- Session
hl.bind("SUPER + L", hl.dsp.global("quickshell:lock"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })

----------------------------
---- APP LAUNCHERS ---------
----------------------------

-- Tap SUPER to toggle fuzzel (release bind)
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/mainMod.sh"), { release = true })

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })

----------------------------
---- WINDOW MANAGEMENT -----
----------------------------

-- Focus
for i = 1, 4 do
	local arrowkey = { "Left", "Right", "Up", "Down" }
	local focusdir = { "l", "r", "u", "d" }
	hl.bind(
		"SUPER + " .. arrowkey[i],
		hl.dsp.focus({ direction = focusdir[i] }),
		{ description = "Window: Focus " .. arrowkey[i] }
	)
end

-- Move window
for i = 1, 4 do
	local arrowkey = { "Left", "Right", "Up", "Down" }
	local focusdir = { "l", "r", "u", "d" }
	hl.bind(
		"SUPER + SHIFT + " .. arrowkey[i],
		hl.dsp.window.move({ direction = focusdir[i] }),
		{ description = "Window: Move " .. arrowkey[i] }
	)
end

-- Close
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("ALT + F4", function()
	hl.exec_cmd('notify-send "Wrong close keybind" "Super+Q to close. Use Alt+F4 for Windows VMs" -a Hyprland')
end, { non_consuming = true })

-- Split ratio
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })

-- Float/Tile
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })

-- Fullscreen
hl.bind(
	mainMod .. " + D",
	hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
	{ description = "Window: Maximize" }
)
hl.bind(
	mainMod .. " + F",
	hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
	{ description = "Window: Fullscreen" }
)
hl.bind(
	mainMod .. " + ALT + F",
	hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }),
	{ description = "Window: Fullscreen spoof" }
)

-- Pin
hl.bind(mainMod .. " + P", hl.dsp.window.pin(), { description = "Window: Pin" })

----------------------------
---- WORKSPACES ------------
----------------------------

-- Focus workspace (1-10)
for i = 1, 10 do
	hl.bind(mainMod .. " + " .. (i % 10), function()
		hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
	end, { description = "Workspace: Focus " .. i })
end

-- Move to workspace (1-10), keep focus on current workspace
for i = 1, 10 do
	hl.bind(mainMod .. " + SHIFT + " .. (i % 10), function()
		hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
	end, { description = "Window: Send to workspace " .. i })
end

-- Focus left/right
hl.bind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Focus left" })
hl.bind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Focus right" })

-- Move to workspace left/right
hl.bind(
	"SUPER + SHIFT + Page_Down",
	hl.dsp.window.move({ workspace = "r+1" }),
	{ description = "Window: Send to workspace right" }
)
hl.bind(
	"SUPER + SHIFT + Page_Up",
	hl.dsp.window.move({ workspace = "r-1" }),
	{ description = "Window: Send to workspace left" }
)

-- Special workspace (scratchpad)
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle scratchpad" })
hl.bind(
	"SUPER + ALT + S",
	hl.dsp.window.move({ workspace = "special:special", follow = false }),
	{ description = "Window: Send to scratchpad" }
)

----------------------------
---- ZOOM ------------------
----------------------------

local function zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	if (zoomvalue + value) > 3.0 then
		hl.config({ cursor = { zoom_factor = 3.0 } })
	elseif (zoomvalue + value) < 1.0 then
		hl.config({ cursor = { zoom_factor = 1.0 } })
	else
		hl.config({ cursor = { zoom_factor = zoomvalue + value } })
	end
end
hl.bind("SUPER + Minus", function()
	zoomfunction(-0.3)
end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function()
	zoomfunction(0.3)
end, { repeating = true, description = "Screen: Zoom in" })
