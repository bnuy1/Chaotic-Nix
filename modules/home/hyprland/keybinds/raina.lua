-- COLEMAK keybinds for raina
-- Profile: raina (COLEMAK variant)
-- COLEMAK remaps: R->F, T->G, Y->J, U->L, I->U, O->Y, P->;
--                 A->A, S->R, D->S, F->T, G->D, H->H, J->N, K->E, L->I, ;->O

local mainMod = "SUPER"

----------------------------
---- APP LAUNCHERS ---------
----------------------------

-- In COLEMAK, 'T' is where 'G' is in QWERTY
-- But Hyprland uses the key name after layout conversion
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(terminal), { description = "App: Terminal (COLEMAK G)" })
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })

----------------------------
---- WINDOW MANAGEMENT -----
----------------------------

-- Focus (COLEMAK: I/U/E/N for arrows)
hl.bind(mainMod .. " + I", hl.dsp.focus({ direction = "up" }), { description = "Window: Focus up" })
hl.bind(mainMod .. " + N", hl.dsp.focus({ direction = "down" }), { description = "Window: Focus down" })
hl.bind(mainMod .. " + E", hl.dsp.focus({ direction = "left" }), { description = "Window: Focus left" })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Window: Focus right" })

-- Move window (COLEMAK: SHIFT + I/U/E/N)
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.window.move({ direction = "up" }), { description = "Window: Move up" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ direction = "down" }), { description = "Window: Move down" })
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.window.move({ direction = "left" }), { description = "Window: Move left" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), { description = "Window: Move right" })

-- Close (Q is still Q in COLEMAK)
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("ALT + F4", function()
    hl.exec_cmd("notify-send \"Wrong close keybind\" \"Super+Q to close. Use Alt+F4 for Windows VMs\" -a Hyprland")
end, { non_consuming = true })

-- Split ratio (COLEMAK: Y and ; for split)
hl.bind("SUPER + Y", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + O", hl.dsp.layout("splitratio +0.1"), { repeating = true })

-- Float/Tile (COLEMAK: A is still A)
hl.bind(mainMod .. " + ALT + A", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })

-- Fullscreen
hl.bind(mainMod .. " + C", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind(mainMod .. " + ALT + D", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Window: Fullscreen spoof" })

-- Pin
hl.bind(mainMod .. " + X", hl.dsp.window.pin(), { description = "Window: Pin" })

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

-- Focus left/right (COLEMAK: use brackets or arrow keys)
hl.bind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Focus left" })
hl.bind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Focus right" })

-- Move to workspace left/right
hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Window: Send to workspace right" })
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Window: Send to workspace left" })

-- Special workspace (scratchpad)
hl.bind("SUPER + T", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle scratchpad" })
hl.bind("SUPER + ALT + T", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to scratchpad" })

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
hl.bind("SUPER + Minus", function() zoomfunction(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoomfunction(0.3) end, { repeating = true, description = "Screen: Zoom in" })
