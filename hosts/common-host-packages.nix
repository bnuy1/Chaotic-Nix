{ pkgs, ... }:

{
  custom.allowUnfreePackages = [
    "spotify"
  ];

  environment.systemPackages = with pkgs; [
    # Development
    nodejs
    opencv
    cmake
    gnumake
    pkg-config

    plymouth
    hyprsunset
    # System utils
    awww
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
    # You prob want this
    brightnessctl
    blueman
    exfatprogs
    # Gui
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
