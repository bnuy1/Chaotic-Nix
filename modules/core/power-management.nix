{ lib, vars, ... }:
let
  suspendEnable = vars.suspendEnable or true;
  hibernateEnable = vars.hibernateEnable or false;

  # Valid: "power-profiles-daemon", "tlp", "thermald", or null
  pmu = vars.powerManagementUtility or "power-profiles-daemon";
in
{
  config = {
    systemd.targets = {
      suspend.enable = suspendEnable;
      hibernate.enable = hibernateEnable;
      hybrid-sleep.enable = suspendEnable && hibernateEnable;
    };

    services.logind.settings.Login = {
      # Lid close locks; lockdown user service handles screen-off + battery suspend
      HandleLidSwitch = "lock";
      HandlePowerKey = "poweroff";
    };

    services.tlp.enable = pmu == "tlp";

    # TLP USB autosuspend
    services.tlp.settings = lib.mkIf (pmu == "tlp") {
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_PRINTER = 1;
      USB_EXCLUDE_PHONE = 1;
      USB_EXCLUDE_BTUSB = 0;
      USB_EXCLUDE_AUDIO = 0;
      USB_EXCLUDE_WWAN = 0;
    };

    services.thermald.enable = pmu == "thermald" || pmu == "tlp";

    # powersave governor on TLP systems
    powerManagement.cpuFreqGovernor = lib.mkIf (pmu == "tlp") "powersave";
  };
}
