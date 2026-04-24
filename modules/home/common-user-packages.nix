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
    gzip
    gnome-multi-writer
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
    libreoffice
    pywal16
    git
    curl
    wget
    htop
    librewolf
    kitty
    vesktop
    prismlauncher
    signal-desktop
    dunst
    kitty
    lshw
    zoxide
    grc
    #fish plugins are downloaded in the host files
  ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      set -g __done_min_cmd_duration 10000
      set -g __done_notify_sound 1    
      set -g __done_notification_urgency_level low
      set -g __done_notification_urgency_level_failure normal
      set -g __done_allow_nongraphical 1
      set -g __done_notification_command "echo \$title \$message"
      # Make manpages colorfull without the colored-man-pages because i couldent get it to work with 2 hours of trying
      set -gx MANPAGER "nvim +Man!"
      zoxide init fish | source
    '';

    shellAliases = {
      ls = "ls --color";
      nrs = "sudo nixos-rebuild switch";
      nnix = "sudo nvim /etc/nixos";
      gfnix = "kitten ssh mal@fuck.wyfi.top -p 49357";
      gf = "kitten ssh malachy@fuck.wyfi.top -p 28740";
    };

    plugins = [
      {
        name = "done";
        src = pkgs.fishPlugins.done;
      }
      {
        name = "grc";
        src = pkgs.fishPlugins.grc;
      }
      {
        name = "pure-prompt";
        src = pkgs.fishPlugins.pure;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair;
      }
    ];
  };
}
