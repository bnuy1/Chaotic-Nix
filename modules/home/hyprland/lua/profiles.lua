-- Profile system for multi-user/keyboard layout support
-- This file is Nix-generated from variables.nix
-- DO NOT EDIT MANUALLY

-- Profile list: { name = "username", layout = "us", variant = "" }
-- NixOS generates this based on declared users and keyboardVariant
profiles = {
    { name = "bnuy",  layout = "us",    variant = "" },
    { name = "raina", layout = "us",    variant = "colemak" },
}

-- Find current user's profile index
current_user = os.getenv("USER") or "bnuy"
current_profile_index = 1

for i, profile in ipairs(profiles) do
    if profile.name == current_user then
        current_profile_index = i
        break
    end
end

-- Profile switcher: cycle to next profile
function cycle_profile()
    current_profile_index = current_profile_index + 1
    if current_profile_index > #profiles then
        current_profile_index = 1
    end

    local profile = profiles[current_profile_index]

    -- Update keyboard layout
    hl.config({
        input = {
            kb_layout = profile.layout,
            kb_variant = profile.variant,
        },
    })

    -- Reload keybinds for new profile
    load_profile_keybinds(profile.name)

    -- Notify user
    hl.notification.create({
        text = "Profile: " .. profile.name .. " (" .. profile.layout .. (profile.variant ~= "" and "+" .. profile.variant or "") .. ")",
        duration = 2000,
    })
end

-- Load keybinds for a specific profile
function load_profile_keybinds(profile_name)
    local bind_file = HOME .. "/.config/hypr/keybinds/" .. profile_name .. ".lua"
    if is_file_exists(bind_file) then
        -- Clear existing binds (Hyprland handles this on reload)
        dofile(bind_file)
    else
        -- Fallback to QWERTY binds
        dofile(HOME .. "/.config/hypr/keybinds/bnuy.lua")
    end
end

-- Enable profile switcher only if multiple profiles exist
if #profiles > 1 then
    hl.bind("SUPER + SHIFT + K", function() cycle_profile() end,
        { description = "Profile: Switch to next profile" })
end
