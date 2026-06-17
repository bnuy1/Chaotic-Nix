{ pkgs, vars, ... }: {
  programs.hyprland.enable = vars.displayManager == "sddm";
  programs.uwsm.enable = vars.displayManager == "sddm";
  services.hyprpolkitagent.enable = vars.displayManager == "sddm";

  # Enable xdg-desktop-portal and register backends
  # Portals run as user services via D-Bus activation.
  xdg.portal = {
    enable = vars.displayManager == "sddm";
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
}
  
