{ vars, dm, config, ... }:

let
  # Filter users who get full HM config (minimal = false)
  # Only these users will have Hyprland configs
  fullUsers = builtins.filter (user: !(user.minimal or false)) vars.users;

  # Generate profiles.lua from variables.nix
  # This creates the profile list for the keybind switcher
  profilesLua = ''
    -- Profile system for multi-user/keyboard layout support
    -- Nix-generated from variables.nix - DO NOT EDIT MANUALLY

    profiles = {
    ${builtins.concatStringsSep "\n" (map (user: ''
      { name = "${user.name}", layout = "us", variant = "" },
    '') fullUsers)}
    }

    -- Find current user's profile index
    current_user = os.getenv("USER") or "${if builtins.length fullUsers > 0 then (builtins.head fullUsers).name else "bnuy"}"
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
            dofile(bind_file)
        else
            -- Fallback to first profile
            dofile(HOME .. "/.config/hypr/keybinds/${if builtins.length fullUsers > 0 then (builtins.head fullUsers).name else "bnuy"}.lua")
        end
    end

    -- Enable profile switcher only if multiple profiles exist
    if #profiles > 1 then
        hl.bind("SUPER + SHIFT + K", function() cycle_profile() end,
            { description = "Profile: Switch to next profile" })
    end
  '';

in
{
  imports = [
    ./xdg-desktop-portal.nix
    ../quickshell
  ];

  wayland.windowManager.hyprland = {
    enable = dm.graphical;
    xwayland.enable = true;
    configType = "lua";
  };

  xdg.configFile = {
    # Lua config files
    "hypr/hyprland.lua".source = ./hyprland.lua;
    "hypr/lib.lua".source = ./lib.lua;
    "hypr/appearance.lua".source = ./appearance.lua;
    "hypr/autostart.lua".source = ./autostart.lua;
    "hypr/rules.lua".source = ./rules.lua;
    "hypr/binds.lua".source = ./binds.lua;

    # Nix-generated profiles.lua
    "hypr/profiles.lua".text = profilesLua;

    # Keybind profiles
    "hypr/keybinds/bnuy.lua".source = ./keybinds/bnuy.lua;
    "hypr/keybinds/raina.lua".source = ./keybinds/raina.lua;

    # Hypridle stays as hyprlang (hybrid approach)
    "hypr/hypridle.conf".source = ./hypridle.conf;

    # Other configs
    "hypr/hyprsunset.conf".source = ./hyprsunset.conf;

    # Scripts
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
  };
}
