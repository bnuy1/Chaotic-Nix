{ vars, dm, config, ... }:

let
  palette = config.lib.stylix.colors;

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

  # Generate Stylix palette JSON for Quickshell
  paletteJson = builtins.toJSON {
    base00 = "#${palette.base00}";
    base01 = "#${palette.base01}";
    base02 = "#${palette.base02}";
    base03 = "#${palette.base03}";
    base04 = "#${palette.base04}";
    base05 = "#${palette.base05}";
    base06 = "#${palette.base06}";
    base07 = "#${palette.base07}";
    base08 = "#${palette.base08}";
    base09 = "#${palette.base09}";
    base0A = "#${palette.base0A}";
    base0B = "#${palette.base0B}";
    base0C = "#${palette.base0C}";
    base0D = "#${palette.base0D}";
    base0E = "#${palette.base0E}";
    base0F = "#${palette.base0F}";
  };
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
    "hypr/hyprland.lua".source = ./lua/hyprland.lua;
    "hypr/lib.lua".source = ./lua/lib.lua;
    "hypr/appearance.lua".source = ./lua/appearance.lua;
    "hypr/autostart.lua".source = ./lua/autostart.lua;
    "hypr/rules.lua".source = ./lua/rules.lua;
    "hypr/binds.lua".source = ./lua/binds.lua;

    # Nix-generated profiles.lua
    "hypr/profiles.lua".text = profilesLua;

    # Keybind profiles
    "hypr/keybinds/bnuy.lua".source = ./lua/keybinds/bnuy.lua;
    "hypr/keybinds/raina.lua".source = ./lua/keybinds/raina.lua;

    # Stylix palette export for Quickshell
    "hypr/palette.json".text = paletteJson;

    # Hyprlock and Hypridle stay as hyprlang (hybrid approach)
    "hypr/hyprlock.conf".text = ''
      # Star it up: https://github.com/hyprwm/hyprlock

      background {
          monitor =
          path = $HOME/Pictures/wallpapers
          color = rgb(${palette.base00})
          blur_passes = 2
          blur_size = 6
          noise = 0.01
          contrast = 0.9
          brightness = 0.8
          vibrancy = 0.2
          vibrancy_darkness = 0.0
      }

      input-field {
          monitor =
          size = 300, 60
          outline_thickness = 3
          dots_size = 0.2
          dots_spacing = 0.35
          dots_center = true
          outer_color = rgb(${palette.base0D})
          inner_color = rgb(${palette.base01})
          font_color = rgb(${palette.base05})
          fade_on_empty = false
          placeholder_text = <i>Password...</i>
          hide_input = false
          position = 0, -80
          halign = center
          valign = center
      }
    '';
    "hypr/hypridle.conf".source = ./hypridle.conf;

    # Other configs
    "hypr/hyprsunset.conf".source = ./hyprsunset.conf;

    # Scripts
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };

    # Environment variable for Stylix palette
    "hypr/env.sh".text = ''
      export HYPRLAND_PALETTE='${paletteJson}'
    '';
  };
}
