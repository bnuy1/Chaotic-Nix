{ lib, ... }:

{
  programs.kitty = lib.mkForce {
    enable = true;

    settings = {
      # Fonts
      font_family = "Iosevka";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 15.0;

      # Window behavior
      confirm_os_window_close = 3;

      # Appearance
      background_opacity = "0.6";
      dynamic_background_opacity = true;
      background_blur = 5;
      window_padding_width = 10;

      # Misc
      enable_audio_bell = false;
      mouse_hide_wait = "-1.0";

      # Nerd font symbol fallback (keep this if NOT using a Nerd Font as main font)
      symbol_map =
        let
          mappings = [
            "U+23FB-U+23FE"
            "U+2B58"
            "U+E200-U+E2A9"
            "U+E0A0-U+E0A3"
            "U+E0B0-U+E0BF"
            "U+E0C0-U+E0C8"
            "U+E0CC-U+E0CF"
            "U+E0D0-U+E0D2"
            "U+E0D4"
            "U+E700-U+E7C5"
            "U+F000-U+F2E0"
            "U+2665"
            "U+26A1"
            "U+F400-U+F4A8"
            "U+F67C"
            "U+E000-U+E00A"
            "U+F300-U+F313"
            "U+E5FA-U+E62B"
          ];
        in
        (builtins.concatStringsSep "," mappings) + " Symbols Nerd Font";
    };

    # Key mappings go here
    keybindings = {
      "ctrl+equal" = "increase_font_size";
      "ctrl+minus" = "decrease_font_size";
    };
  };
}
