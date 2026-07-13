{ pkgs, lib, vars, ... }:
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
    let
      usersHome = map (u: u.name) (builtins.filter (u: u ? name) (vars.users or [ ]));
    in
      lib.mkAfter ''
        for user in ${builtins.toString usersHome}; do
          compositor="/home/$user/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher"
          if [ -f "$compositor" ]; then
            ${pkgs.libcap}/bin/setcap CAP_SYS_NICE=eip "$compositor" 2>/dev/null || true
          fi
        done
      ''
  );

  # Apply recommended SteamVR settings for Linux AMD.
  # enableLinuxVulkanAsync: async Vulkan submission for lower frame latency.
  # useFacetRenderer: stabilizes frametime consistency.
  # Note: SteamVR may overwrite this file during safe mode resets. Rebuild to re-apply.
  system.activationScripts.steamvr-vrsettings = lib.mkIf (vars.steamEnable or false) (
    let
      usersHome = map (u: u.name) (builtins.filter (u: u ? name) (vars.users or [ ]));
      vrsettings = builtins.toJSON {
        steamvr = {
          enableLinuxVulkanAsync = true;
          useFacetRenderer = true;
        };
      };
    in
      lib.mkAfter ''
        for user in ${builtins.toString usersHome}; do
          vrsettingsfile="/home/$user/.local/share/Steam/config/steamvr.vrsettings"
          mkdir -p "$(dirname "$vrsettingsfile")"
          if [ -f "$vrsettingsfile" ]; then
            ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$vrsettingsfile" <(echo '${vrsettings}') > /tmp/steamvr.vrsettings.tmp \
              && mv /tmp/steamvr.vrsettings.tmp "$vrsettingsfile"
          else
            echo '${vrsettings}' > "$vrsettingsfile"
          fi
          chown "$user:users" "$vrsettingsfile"
        done
      ''
  );

  custom.allowUnfreePackages = lib.optionals (vars.steamEnable or false) [
    "steam"
    "steam-original"
    "steam-unwrapped"
    "steam-run"
  ];
}
