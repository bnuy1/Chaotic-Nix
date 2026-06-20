{ config, pkgs, lib, ... }:
let
  dm = config.custom.displayManagerParsed;
in {
  custom.allowUnfreePackages = [
    "spotify"
  ];

  environment.systemPackages = with pkgs; [
    # CLI
    nodejs
    opencv
    cmake
    gnumake
    pkg-config
    zip
    unzip
    ripgrep
    moreutils
    nano
    bat
    git
    bc
    calc
    man
    tldr
    brightnessctl
    blueman
    exfatprogs
    plymouth
  ] ++ lib.optionals dm.graphical [
    hyprsunset
    orca-slicer
    prusa-slicer
    spotify
    dunst
    jellyfin
    jellyfin-desktop
    kdePackages.dolphin
    moonlight-qt
    element-desktop
  ];
}
