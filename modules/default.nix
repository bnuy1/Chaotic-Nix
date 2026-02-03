{host, ...}: let


in {
   imports = [
      ./nixvim.nix
      ./steam.nix
      ./hyprland/hyprland.nix
  ]; 
}
