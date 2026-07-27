{ lib, vars, ... }:
let
  # -- Suspend / Hibernate ----------------------------------------------------
  suspendEnable = vars.suspendEnable or true;
  hibernateEnable = vars.hibernateEnable or false;

  # -- CPU Power Management ---------------------------------------------------
  # Valid: "power-profiles-daemon", "tlp", "thermald", or null
  pmu = vars.powerManagementUtility or "power-profiles-daemon";
in
{
  config = {
    # -- Suspend / Hibernate Targets ----------------------------------------
    systemd.targets = {
      suspend.enable = suspendEnable;
      hibernate.enable = hibernateEnable;
      hybrid-sleep.enable = suspendEnable && hibernateEnable;
    };

    services.logind.settings.Login = {
      HandleLidSwitch = if suspendEnable then "suspend" else "ignore";
      HandlePowerKey = "poweroff";
    };

    # -- TLP — battery-optimized power management ---------------------------
    services.tlp.enable = pmu == "tlp";

    # TLP USB autosuspend — enabled when TLP is active
    services.tlp.settings = lib.mkIf (pmu == "tlp") {
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_PRINTER = 1;
      USB_EXCLUDE_PHONE = 1;
      USB_EXCLUDE_BTUSB = 0;
      USB_EXCLUDE_AUDIO = 0;
      USB_EXCLUDE_WWAN = 0;
    };

    # -- thermald — Intel CPU thermal management ----------------------------
    services.thermald.enable = pmu == "thermald" || pmu == "tlp";

    # -- CPU governor — powersave for laptops (TLP), kernel default otherwise
    powerManagement.cpuFreqGovernor = lib.mkIf (pmu == "tlp") "powersave";
  };
}
