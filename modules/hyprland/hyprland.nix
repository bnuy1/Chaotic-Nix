{
  host,
  config,
  pkgs,
  lib,
  ...
}:
{ 
  
  programs.hyprland = {
    enable = true;
    withUWSM = true; # recommended for most users
    xwayland.enable = true; # Xwayland can be disabled.
  };

}
