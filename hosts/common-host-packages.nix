{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Development
    nodejs
    ollama
    opencode

    plymouth
    hyprsunset
    wireguard-tools
    # Fish
    fishPlugins.done
    fishPlugins.grc
    fishPlugins.sponge
    fishPlugins.autopair
    fishPlugins.pure
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
    dunst
    jellyfin
    jellyfin-desktop
    kdePackages.dolphin
    moonlight-qt
    element-desktop
  ];
}
