{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";
  
  # Packages that will be downloaded and managed in each users unique home manager instance eg shared accross ALL system users (unless otherwise given a exception)
  home.packages = with pkgs; [
    kdePackages.kate
    fish
    alvr
    swww
    hyprpolkitagent
    krita
    bc
    jq
    dosfstools
    pavucontrol
    arduino
    fastfetch
    waybar
    brightnessctl
    plymouth
    hypridle
    hyprlock
    rofi
    dunst
    libnotify
    inotify-tools
    acpid
    iproute2
    xdg-desktop-portal-hyprland
    libreoffice
    pywal16
    polkit
    neovim
    git
    curl
    wget
    htop
    librewolf
    kitty
    cowsay
    vesktop
    prismlauncher
  ];

  programs.git.enable = true;
  programs.fish.enable = true;
}

