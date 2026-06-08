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
    wireguard-tools
    # System Font
    iosevka
    # System utils
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
