{
  config,
  pkgs,
  ...
}:
{ 
  
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd = {
       enable = true;
       variables = ["--all"];
    };

    settings = {
       "$mod" = "SUPER";
       bind =
         [
           "$mod, J, exec, firefox"
           "$mod, Q, exec, kitty"
         ];
    };


    xwayland.enable = true; 

  };

  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
