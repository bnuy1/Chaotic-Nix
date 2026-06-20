{ lib, ... }:

{
  stylix.targets.rofi.enable = true;

  programs.rofi = {
    enable = true;

    extraConfig = {
      modi = "drun";
      show-icons = true;
      drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
    };
  };
}
