{ config, pkgs, lib, vars, ... }:

let
  # browser pkg + desktop file per name
  # null = none installed
  browsers = {
    librewolf  = { pkg = pkgs.librewolf;  desktop = "librewolf.desktop"; };
    firefox    = { pkg = pkgs.firefox;    desktop = "firefox.desktop"; };
    chromium   = { pkg = pkgs.chromium;   desktop = "chromium.desktop"; };
    google-chrome = { pkg = pkgs.google-chrome; desktop = "google-chrome.desktop"; };
    chrome     = { pkg = pkgs.google-chrome; desktop = "google-chrome.desktop"; };
  };
  # crash early on typos
  chosenBrowser =
    if vars.browser == null then null
    else browsers.${vars.browser} or (throw ''
      unknown browser "${vars.browser}"
      valid: ${builtins.toString (builtins.attrNames browsers)}
    '');
in
{
  # Packages that will be downloaded and managed in each users unique home manager instance eg shared accross ALL system users (unless otherwise given a exception)
  home.packages = with pkgs; [
    kdePackages.kate
    alvr
    awww
    hyprpolkitagent
    krita
    gzip
    gnome-multi-writer
    jq
    dosfstools
    pavucontrol
    arduino
    btop
    fastfetch
    waybar
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
    curl
    wget
    htop
    kitty
    (pkgs.vesktop.overrideAttrs (old: {
      postFixup = old.postFixup + ''
        wrapProgram $out/bin/vesktop --add-flags "--enable-features=WebRTCPipeWireCapturer"
      '';
    }))
    prismlauncher
    signal-desktop
    lshw
    zoxide
    grc
    # terminal ding sound
    libcanberra-gtk3
    nh
    nix-index
    nvd
    #fish plugins are downloaded in the host files
  ] ++ lib.optionals (!(vars.thunarEnable or false)) [
    kdePackages.dolphin-plugins
  ] ++ lib.optional (chosenBrowser != null) chosenBrowser.pkg;

  xdg.configFile."mimeapps.list" = lib.mkIf (!(vars.thunarEnable or false)) {
    text = ''
      [Default Applications]
      inode/directory=dolphin.desktop
      text/plain=kate.desktop
      ${lib.optionalString (chosenBrowser != null) "text/html=${chosenBrowser.desktop}\napplication/pdf=${chosenBrowser.desktop}\n"}
      image/png=krita.desktop
      image/jpeg=krita.desktop
      image/gif=krita.desktop
      image/webp=krita.desktop
      image/svg+xml=krita.desktop
      video/*=vlc.desktop
      audio/*=vlc.desktop
      application/zip=file-roller.desktop
      application/x-tar=file-roller.desktop
      application/x-7z-compressed=file-roller.desktop
      application/x-bzip=file-roller.desktop
      application/x-gzip=file-roller.desktop
      application/x-rar=file-roller.desktop
      application/vnd.rar=file-roller.desktop
      application/gzip=file-roller.desktop
      application/x-xz=file-roller.desktop
      application/vnd.openxmlformats-officedocument.wordprocessingml.document=libreoffice-writer.desktop
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet=libreoffice-calc.desktop
      application/vnd.openxmlformats-officedocument.presentationml.presentation=libreoffice-impress.desktop
      application/msword=libreoffice-writer.desktop
      application/vnd.ms-excel=libreoffice-calc.desktop
      application/vnd.ms-powerpoint=libreoffice-impress.desktop
      application/x-shellscript=kate.desktop
      text/x-c=kate.desktop
      text/x-c++=kate.desktop
      text/x-python=kate.desktop
      text/x-java=kate.desktop
      text/xml=kate.desktop
      text/x-json=kate.desktop
      text/x-markdown=kate.desktop
      text/x-nix=kate.desktop
      text/x-yaml=kate.desktop
      text/x-toml=kate.desktop
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      set -g __done_min_cmd_duration 10000
      set -g __done_notification_urgency_level low
      set -g __done_notification_urgency_level_failure normal
      # Make manpages colorfull without the colored-man-pages because i couldent get it to work with 2 hours of trying
      set -gx MANPAGER "nvim +Man!"
      zoxide init fish | source
      set -g __done_notify_active_window 0
      set -g __done_exclude 'nvim|vi|emacs|tldr|htop|top|nvtop|vim|nano|man|less'
      set -g __done_notification_command "notify-send -u low -i terminal \"\$title\" \"\$message\""
      set -U __done_notify_sound 1
    '';

    shellAliases = {
      ls = "ls --color";
      nrs = "nh os switch";
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
