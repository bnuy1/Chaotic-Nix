{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";
  
  # Packages that will be downloaded and managed in each users unique home manager instance eg shared accross ALL system users (unless otherwise given a exception)
  home.packages = with pkgs; [
    kdePackages.kate
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
    signal-desktop
  ];

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "ls -a --color";
      nrs = "sudo nixos-rebuild switch";
      nnix = "sudo nvim /etc/nixos";
    };
  };

#  programs.git = {
#    enable = true;
#    lfs.enable = true;
#    userName = "Ha2k4r";
#    userEmail = "enigma558@proton.me";
#    extraConfig = {
#      init.defaultBranch = "main";
#      safe.directory = "/etc/nixos";
#    };
#  };


}

