{ lib, vars, ... }:
let
  suspendEnable = vars.suspendEnable or true;
  hibernateEnable = vars.hibernateEnable or false;
in
{
  config = {
    systemd.targets = {
      suspend.enable = suspendEnable;
      hibernate.enable = hibernateEnable;
      hybrid-sleep.enable = suspendEnable && hibernateEnable;
    };

    services.logind.settings.Login = {
      HandleLidSwitch = if suspendEnable then "suspend" else "ignore";
      HandlePowerKey = "poweroff";
    };
  };
}
