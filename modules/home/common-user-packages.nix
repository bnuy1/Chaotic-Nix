{
  config,
  pkgs,
  lib,
  vars,
  dm,
  ...
}:

let
  # browser pkg + desktop file per name
  # null = none installed
  browsers = {
    librewolf = {
      pkg = pkgs.librewolf;
      desktop = "librewolf.desktop";
    };
    firefox = {
      pkg = pkgs.firefox;
      desktop = "firefox.desktop";
    };
    chromium = {
      pkg = pkgs.chromium;
      desktop = "chromium.desktop";
    };
    google-chrome = {
      pkg = pkgs.google-chrome;
      desktop = "google-chrome.desktop";
    };
    chrome = {
      pkg = pkgs.google-chrome;
      desktop = "google-chrome.desktop";
    };
  };
  # crash early on typos
  chosenBrowser =
    if vars.browser == null then
      null
    else
      browsers.${vars.browser} or (throw ''
        unknown browser "${vars.browser}"
        valid: ${builtins.toString (builtins.attrNames browsers)}
      '');
in
{
  home.packages =
    with pkgs;
    [
      # CLI
      gzip
      jq
      dosfstools
      btop
      fastfetch
      inotify-tools
      acpid
      iproute2
      curl
      wget
      lshw
      grc
      # terminal ding sound
      libcanberra-gtk3
      nvd
    ]
    ++ lib.optionals dm.graphical [
      # GUI
      kdePackages.kate
      krita
      gnome-multi-writer
      pavucontrol
      arduino
      libnotify
      libreoffice
      pywal16
      easyeffects
      spicetify-cli
      (pkgs.vesktop.overrideAttrs (old: {
        postFixup = old.postFixup + ''
          wrapProgram $out/bin/vesktop --add-flags "--enable-features=WebRTCPipeWireCapturer --force-dark-mode"
        '';
      }))
      prismlauncher
      signal-desktop
    ]
    ++ lib.optionals ((vars.fileManager or null) == "dolphin" && dm.graphical) [
      kdePackages.dolphin-plugins
    ]
    ++ lib.optional (chosenBrowser != null) chosenBrowser.pkg;

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      set -g __done_min_cmd_duration 10000
      set -g __done_notification_urgency_level low
      set -g __done_notification_urgency_level_failure normal
      set -gx MANPAGER "nvim +Man!"
      set -g __done_notify_active_window 0
      set -U sponge_purge_only_on_exit true
      set -g __done_exclude 'nvim|vi|emacs|tldr|htop|top|nvtop|vim|nano|man|less'
      set -g __done_notification_command "notify-send -u low -i terminal \"\$title\" \"\$message\""
      set -U __done_notify_sound 1
    '';

    # tty1 autologin via uwsm; guarded against SSH/tty2-6/already-graphical shells
    loginShellInit = lib.mkIf dm.graphical ''
      if not set -q WAYLAND_DISPLAY; and not set -q DISPLAY; and not set -q SSH_CONNECTION; and string match -q '/dev/tty1' (tty)
          exec uwsm -g -1 start start-hyprland
      end
    '';

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
        name = "autopair";
        src = pkgs.fishPlugins.autopair;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge;
      }
    ];
  };
}
