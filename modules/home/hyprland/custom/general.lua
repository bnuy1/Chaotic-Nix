-- Appearance: gaps/borders + end4 animations; colors via custom/colors.lua
-- (seeded once by Nix; preserved across builds)

hl.monitor({
	output = "desc:ASUSTek COMPUTER INC ASUS VG249 0x00009A40",
	mode = "1920x1080@144",
	position = "0x0",
	scale = 1,
	vrr = 1,
})

hl.monitor({
	output = "desc:Acer Technologies SB220Q 0x203022C0",
	mode = "1920x1080@60",
	position = "auto-center-left",
	scale = 1,
	vrr = 0,
})

hl.monitor({
	output = "desc:Panasonic Industry Company 11SP_HTIB",
	mode = "highres",
	position = "auto-center-up",
	scale = 2,
	vrr = 1,
})

-- Wildcard fallback
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Permissions

hl.config({
	ecosystem = {
		enforce_permissions = true,
	},
})

-- Nix store paths are RE2-matched against /proc/<pid>/exe (no globs); reload on start
hl.permission("/nix/store/[a-z0-9]{32}-grim-[0-9.]*/bin/grim", "screencopy", "allow")
hl.permission("/nix/store/[a-z0-9]{32}-quickshell-[0-9.]*/bin/.quickshell-wrapped", "screencopy", "allow")
hl.permission(
	"/nix/store/[a-z0-9]{32}-xdg-desktop-portal-hyprland-[0-9.]*/libexec/.xdg-desktop-portal-hyprland-wrapped",
	"screencopy",
	"allow"
)
hl.permission("/nix/store/[a-z0-9]{32}-wf-recorder-[0-9.]*/bin/wf-recorder", "screencopy", "allow")
hl.permission("/nix/store/[a-z0-9]{32}-hyprpicker-[0-9.]*/bin/hyprpicker", "screencopy", "allow")
hl.permission("/nix/store/[a-z0-9]{32}-hyprland-[0-9.]*/bin/hyprpm", "plugin", "allow")

-- Look and feel

-- General: gaps + end4's settings
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 5,
		gaps_workspaces = 50,
		border_size = 1,

		resize_on_border = true,
		no_focus_fallback = true,
		allow_tearing = true,
		layout = "dwindle",

		snap = {
			enabled = true,
			window_gap = 4,
			monitor_gap = 5,
			respect_gaps = true,
		},
	},

	decoration = {
		-- end4's rounding (squircle style)
		rounding = 18,
		rounding_power = 2.5,

		-- Blur (end4's settings)
		blur = {
			enabled = true,
			xray = true,
			special = false,
			new_optimizations = true,
			size = 8,
			passes = 2,
			brightness = 1,
			noise = 0.05,
			contrast = 0.89,
			vibrancy = 0.5,
			vibrancy_darkness = 0.5,
			popups = false,
			popups_ignorealpha = 0.6,
			input_methods = true,
			input_methods_ignorealpha = 0.8,
		},

		-- Shadow (end4's settings)
		shadow = {
			enabled = true,
			range = 20,
			offset = { 0, 2 },
			render_power = 10,
			color = "rgba(00000020)",
		},

		-- Dim (end4's settings)
		dim_inactive = true,
		dim_strength = 0.05,
		dim_special = 0.2,
	},

	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
		smart_split = false,
		smart_resizing = false,
	},

	master = {
		new_status = "master",
	},

	scrolling = {
		fullscreen_on_one_column = true,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		vrr = 1,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		animate_manual_resizes = false,
		animate_mouse_windowdragging = false,
		enable_swallow = false,
		swallow_regex = "(foot|kitty|allacritty|Alacritty)",
		on_focus_under_fullscreen = 2,
		allow_session_lock_restore = true,
		session_lock_xray = true,
		initial_workspace_tracking = false,
		focus_on_activate = true,
	},

	binds = {
		scroll_event_delay = 0,
		hide_special_on_workspace_change = true,
	},

	cursor = {
		zoom_factor = 1,
		zoom_rigid = false,
		zoom_disable_aa = true,
		hotspot_padding = 1,
	},

	xwayland = {
		force_zero_scaling = true,
	},

	input = {
		kb_layout = "us",
		kb_variant = "",
		numlock_by_default = true,
		repeat_delay = 250,
		repeat_rate = 35,
		follow_mouse = 1,
		off_window_axis_events = 2,

		touchpad = {
			natural_scroll = false,
			disable_while_typing = true,
			clickfinger_behavior = true,
			scroll_factor = 0.7,
		},
	},

	gestures = {
		workspace_swipe_distance = 700,
		workspace_swipe_cancel_ratio = 0.2,
		workspace_swipe_min_speed_to_force = 5,
		workspace_swipe_direction_lock = true,
		workspace_swipe_direction_lock_threshold = 10,
		workspace_swipe_create_new = true,
	},
})

-- Per-device config
 hl.device({
 	name = "epic-mouse-v1",
 	sensitivity = -0.5,
 })

-- Animation curves

-- end4's expressive curves
hl.curve("expressiveFastSpatial", {
	type = "bezier",
	points = { { 0.42, 1.67 }, { 0.21, 0.90 } },
})

hl.curve("expressiveSlowSpatial", {
	type = "bezier",
	points = { { 0.39, 1.29 }, { 0.35, 0.98 } },
})

hl.curve("expressiveDefaultSpatial", {
	type = "bezier",
	points = { { 0.38, 1.21 }, { 0.22, 1.00 } },
})

hl.curve("emphasizedDecel", {
	type = "bezier",
	points = { { 0.05, 0.7 }, { 0.1, 1 } },
})

hl.curve("emphasizedAccel", {
	type = "bezier",
	points = { { 0.3, 0 }, { 0.8, 0.15 } },
})

hl.curve("standardDecel", {
	type = "bezier",
	points = { { 0, 0 }, { 0, 1 } },
})

hl.curve("menu_decel", {
	type = "bezier",
	points = { { 0.1, 1 }, { 0, 1 } },
})

hl.curve("menu_accel", {
	type = "bezier",
	points = { { 0.52, 0.03 }, { 0.72, 0.08 } },
})

hl.curve("stall", {
	type = "bezier",
	points = { { 1, -0.1 }, { 0.7, 0.85 } },
})

-- Animations

-- Windows
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
	style = "popin 80%",
})

hl.animation({
	leaf = "fadeIn",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
})

hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 2,
	bezier = "emphasizedDecel",
	style = "popin 90%",
})

hl.animation({
	leaf = "fadeOut",
	enabled = true,
	speed = 2,
	bezier = "emphasizedDecel",
})

hl.animation({
	leaf = "windowsMove",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
	style = "slide",
})

hl.animation({
	leaf = "border",
	enabled = true,
	speed = 10,
	bezier = "emphasizedDecel",
})

-- Layers
hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 2.7,
	bezier = "emphasizedDecel",
	style = "popin 93%",
})

hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 2.4,
	bezier = "menu_accel",
	style = "popin 94%",
})

-- Fade
hl.animation({
	leaf = "fadeLayersIn",
	enabled = true,
	speed = 0.5,
	bezier = "menu_decel",
})

hl.animation({
	leaf = "fadeLayersOut",
	enabled = true,
	speed = 2.7,
	bezier = "stall",
})

-- Workspaces
hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 7,
	bezier = "menu_decel",
	style = "slide",
})

-- Special workspace
hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 2.8,
	bezier = "emphasizedDecel",
	style = "slidevert",
})

hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 1.2,
	bezier = "emphasizedAccel",
	style = "slidevert",
})

-- Zoom
hl.animation({
	leaf = "zoomFactor",
	enabled = true,
	speed = 3,
	bezier = "standardDecel",
})
