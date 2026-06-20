{ lib, vars, ... }:
{
  services.sunshine = {
    enable = vars.sunshineEnable or false;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      port = 47990;
      origin_web_ui_allowed = "wan";
    };
  };
}
