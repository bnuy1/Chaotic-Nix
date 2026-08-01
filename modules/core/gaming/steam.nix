{
  pkgs,
  lib,
  vars,
  ...
}:
let
  usersHome = map (u: u.name) (builtins.filter (u: u ? name) (vars.users or [ ]));
in
{
  programs = {
    steam = {
      enable = vars.steamEnable or false;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      package = pkgs.steam.override {
        extraProfile = ''
          # Allows Monado/WiVRn to be used
          export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
          # Fixes timezones on VRChat
          unset TZ
        '';
      };

    };

    gamescope = {
      enable = vars.steamEnable or false;
      capSysNice = true;
      args = [
        "--rt"
        "--expose-wayland"
      ];
    };

    gamemode.enable = vars.steamEnable or false;
  };

  hardware.graphics = lib.mkIf (vars.steamEnable or false) {
    extraPackages = with pkgs; [ mangohud ];
    extraPackages32 = with pkgs; [ mangohud ];
  };

  # SteamVR's compositor needs realtime scheduling without prompting for root
  users.groups.realtime = lib.mkIf (vars.steamEnable or false) { };

  security.pam.loginLimits = lib.optionals (vars.steamEnable or false) [
    {
      domain = "@realtime";
      type = "-";
      item = "rtprio";
      value = "99";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "nice";
      value = "-20";
    }
  ];

  # pkexec can't set CAP_SYS_NICE on NixOS; pre-set it on known SteamVR paths
  system.activationScripts.steamvr-setcap = lib.mkIf (vars.steamEnable or false) (
    lib.mkAfter ''
      for user in ${builtins.toString usersHome}; do
        compositor="/home/$user/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher"
        if [ -f "$compositor" ]; then
          ${pkgs.libcap}/bin/setcap CAP_SYS_NICE=eip "$compositor" 2>/dev/null || true
        fi
      done
    ''
  );

  # gamemode polkit rules so gamemoded can change the CPU governor without auth
  environment.etc = lib.mkIf (vars.steamEnable or false) {
    "polkit-1/rules.d/20-gamemode.rules".source =
      "${pkgs.gamemode}/share/polkit-1/rules.d/gamemode.rules";
    "polkit-1/actions/com.feralinteractive.GameMode.policy".source =
      "${pkgs.gamemode}/share/polkit-1/actions/com.feralinteractive.GameMode.policy";
  };

  custom.allowUnfreePackages = lib.optionals (vars.steamEnable or false) [
    "steam"
    "steam-original"
    "steam-unwrapped"
    "steam-run"
  ];
}
