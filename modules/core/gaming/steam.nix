{ pkgs, lib, vars, ... }:
let
  usersHome = map (u: u.name) (builtins.filter (u: u ? name) (vars.users or [ ]));
  vrsettings = {
    steamvr = {
      motionSmoothing = false;
      enableLinuxVulkanAsync = true;
      useFacetRenderer = true;
      disableAsync = true;
    };
  };
  vrsettingsJSON = builtins.toJSON vrsettings;
in
{
  programs = {
    steam = {
      enable = vars.steamEnable or false;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = false;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
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

  # SteamVR's compositor needs realtime scheduling for low-latency tracking.
  # Without PAM limits, SteamVR prompts for root to set SCHED_FIFO priority.
  users.groups.realtime = lib.mkIf (vars.steamEnable or false) { };

  security.pam.loginLimits = lib.optionals (vars.steamEnable or false) [
    { domain = "@realtime"; type = "-"; item = "rtprio"; value = "99"; }
    { domain = "@realtime"; type = "-"; item = "memlock"; value = "unlimited"; }
    { domain = "@realtime"; type = "-"; item = "nice"; value = "-20"; }
  ];

  # SteamVR tries to use pkexec to set CAP_SYS_NICE on vrcompositor-launcher.
  # pkexec doesn't work well on NixOS, so pre-set the capability on known paths.
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

  environment.sessionVariables = lib.mkIf (vars.steamEnable or false) {
    RADV_DEBUG = "nocompute";
  };

  # SteamVR settings overrides for Linux AMD.
  # motionSmoothing: disable async reprojection — on Linux/RADV async only
  #   corrects rotation, not translation, producing unplayable seesaw yanking.
  # enableLinuxVulkanAsync: async Vulkan submission for lower frame latency.
  # useFacetRenderer: stabilizes frametime consistency.
  # disableAsync: secondary async disable (backup for motionSmoothing).
  # vrlink driver ignores encodeWidth/targetBandwidth from steamvr.vrsettings —
  #   it uses its own automatic calculation based on GPU speed benchmarks.
  #
  # Applied by activation script on nixos-rebuild. If Steam overwrites the file
  # (safe mode, updates), re-run: nixos-rebuild switch to restore.
  system.activationScripts.steamvr-vrsettings = lib.mkIf (vars.steamEnable or false) (
    lib.mkAfter ''
      for user in ${builtins.toString usersHome}; do
        vrsettingsfile="/home/$user/.local/share/Steam/config/steamvr.vrsettings"
        mkdir -p "$(dirname "$vrsettingsfile")"
        if [ -f "$vrsettingsfile" ]; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$vrsettingsfile" <(echo '${vrsettingsJSON}') > /tmp/steamvr.vrsettings.tmp \
            && mv /tmp/steamvr.vrsettings.tmp "$vrsettingsfile"
        else
          echo '${vrsettingsJSON}' > "$vrsettingsfile"
        fi
        chown "$user:users" "$vrsettingsfile"
      done
    ''
  );

  # Install gamemode polkit rules and actions so gamemoded can change
  # CPU governor without authentication (requires user in gamemode group).
  environment.etc = lib.mkIf (vars.steamEnable or false) {
    "polkit-1/rules.d/20-gamemode.rules".source = "${pkgs.gamemode}/share/polkit-1/rules.d/gamemode.rules";
    "polkit-1/actions/com.feralinteractive.GameMode.policy".source = "${pkgs.gamemode}/share/polkit-1/actions/com.feralinteractive.GameMode.policy";
  };

  custom.allowUnfreePackages = lib.optionals (vars.steamEnable or false) [
    "steam"
    "steam-original"
    "steam-unwrapped"
    "steam-run"
  ];
}
