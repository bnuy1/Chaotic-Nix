{ vars, ... }: {
  programs.hyprland.enable = vars.displayManager == "sddm";
  programs.uwsm.enable = vars.displayManager == "sddm";
}
  
