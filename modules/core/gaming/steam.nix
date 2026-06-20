{ pkgs, lib, vars, ... }:
{
  programs = {
    steam = {
      enable = vars.steamEnable or false;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
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

  custom.allowUnfreePackages = lib.optionals (vars.steamEnable or false) [
    "steam"
    "steam-original"
    "steam-unwrapped"
    "steam-run"
  ];
}
