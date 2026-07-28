-- QWERTY keybinds for bnuy
-- Profile: bnuy (QWERTY, no variant)

local mainMod = "SUPER"

----------------------------
---- APP LAUNCHERS ---------
----------------------------

-- Tap SUPER to toggle rofi (release bind)
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/mainMod.sh"), { release = true })

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu), { description = "App: Launcher" })

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

-- Move to workspace (1-10)
for i = 1, 10 do
	hl.bind(mainMod .. " + ALT + " .. (i % 10), function()
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

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

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
