{ lib, vars, ... }:
let
  suspendEnable = vars.suspendEnable or true;
  hibernateEnable = vars.hibernateEnable or false;
  pmu = vars.powerManagementUtility or "power-profiles-daemon"; # Valid: "power-profiles-daemon", "tlp", "thermald", or null
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

    # TLP — battery-optimized power management
    services.tlp.enable = pmu == "tlp";

    # thermald — Intel CPU thermal management
    services.thermald.enable = pmu == "thermald" || pmu == "tlp";

    # CPU governor — powersave for laptops (TLP), kernel default otherwise
    powerManagement.cpuFreqGovernor = lib.mkIf (pmu == "tlp") "powersave";
  };
}
