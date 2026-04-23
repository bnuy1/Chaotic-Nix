{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  noctaliaPkg = inputs.noctalia.packages.${system}.default;
  configDir = "${noctaliaPkg}/share/noctalia-shell";

  # The script Noctalia will trigger when the wallpaper changes
  stylixSyncHook = pkgs.writeShellScriptBin "noctalia-stylix-sync" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Noctalia passes the current wallpaper path as $1
    NEW_WALL="$1"
    notify-send "Noctalia" "$(basename "$NEW_WALL") Wallpaper synced to stylix! Will apply on next rebuild."
  '';
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];
  # Install the Noctalia package
  home.packages = [
    stylixSyncHook
    noctaliaPkg
    pkgs.quickshell # Ensure quickshell is available for the service
  ];

  programs.noctalia-shell = {
    enable = true;
    settings = {
      calendar = {
        cards = [
          {
            enabled = true;
            id = "calendar-header-card";
          }
          {
            enabled = true;
            id = "calendar-month-card";
          }
          {
            enabled = true;
            id = "weather-card";
          }
        ];
      };
      bar = {
        widgets = {
          left = [
            {
              colorizeSystemIcon = "none";
              customIconPath = "";
              enableColorization = false;
              icon = "rocket";
              iconColor = "none";
              id = "Launcher";
              useDistroLogo = true;
            }
            {
              clockColor = "none";
              customFont = "";
              formatHorizontal = "h:mm a ddd, MMM dd";
              formatVertical = "h mm a - dd MM";
              id = "Clock";
              tooltipFormat = "h:mm a ddd, MMM dd";
              useCustomFont = false;
            }
            {
              compactMode = true;
              diskPath = "/";
              iconColor = "none";
              id = "SystemMonitor";
              showCpuCores = false;
              showCpuFreq = true;
              showCpuTemp = true;
              showCpuUsage = true;
              showDiskAvailable = true;
              showDiskUsage = true;
              showDiskUsageAsPercent = true;
              showGpuTemp = true;
              showLoadAverage = false;
              showMemoryAsPercent = false;
              showMemoryUsage = true;
              showNetworkStats = false;
              showSwapUsage = false;
              textColor = "none";
              useMonospaceFont = true;
              usePadding = false;
            }
            {
              colorizeIcons = false;
              hideMode = "hidden";
              id = "ActiveWindow";
              maxWidth = 145;
              scrollingMode = "hover";
              showIcon = true;
              textColor = "none";
              useFixedWidth = false;
            }
            {
              compactMode = false;
              hideMode = "hidden";
              hideWhenIdle = false;
              id = "MediaMini";
              maxWidth = 300;
              panelShowAlbumArt = true;
              scrollingMode = "hover";
              showAlbumArt = true;
              showArtistFirst = true;
              showProgressRing = false;
              showVisualizer = true;
              textColor = "none";
              useFixedWidth = false;
              visualizerType = "linear";
            }
          ];
          center = [
            {
              characterCount = 2;
              colorizeIcons = false;
              emptyColor = "secondary";
              enableScrollWheel = true;
              focusedColor = "primary";
              followFocusedScreen = false;
              fontWeight = "bold";
              groupedBorderOpacity = 1;
              hideUnoccupied = false;
              iconScale = 1;
              id = "Workspace";
              labelMode = "index";
              occupiedColor = "secondary";
              pillSize = 0.8;
              showApplications = false;
              showApplicationsHover = false;
              showBadge = true;
              showLabelsOnlyWhenOccupied = true;
              unfocusedIconsOpacity = 1;
            }
          ];
          right = [
            {
              id = "Tray";
            }
            {
              hideWhenZero = false;
              hideWhenZeroUnread = false;
              iconColor = "none";
              id = "NotificationHistory";
              showUnreadBadge = true;
              unreadBadgeColor = "primary";
            }
            {
              deviceNativePath = "__default__";
              displayMode = "graphic-clean";
              hideIfIdle = false;
              hideIfNotDetected = true;
              id = "Battery";
              showNoctaliaPerformance = false;
              showPowerProfiles = true;
            }
            {
              displayMode = "onhover";
              iconColor = "none";
              id = "Volume";
              middleClickCommand = "pwvucontrol || pavucontrol";
              textColor = "none";
            }
            {
              id = "Brightness";
            }
            {
              id = "ControlCenter";
            }
          ];
        };
      };
      location = {
        name = "Plymouth";
        weatherEnabled = true;
        weatherShowEffects = true;
        useFahrenheit = true;
        use12hourFormat = true;
        showWeekNumberInCalendar = true;
        showCalendarEvents = true;
        showCalendarWeather = true;
        analogClockInCalendar = false;
        firstDayOfWeek = -1;
        hideWeatherTimezone = false;
        hideWeatherCityName = false;
      };
      wallpaper = {
        enabled = true;
        overviewEnabled = false;
        directory = "${config.home.homeDirectory}/Pictures/wallpapers";
        monitorDirectories = [ ];
        enableMultiMonitorDirectories = false;
        showHiddenFiles = false;
        viewMode = "single";
        setWallpaperOnAllMonitors = true;
        fillMode = "crop";
        wallpaperChangeMode = "random";
        randomIntervalSec = 3600;
        transitionDuration = 1500;
        transitionType = "random";
        skipStartupTransition = false;
        transitionEdgeSmoothness = 0.05;
        panelPosition = "follow_bar";
        hideWallpaperFilenames = false;
        overviewBlur = 0.4;
        overviewTint = 0.6;
        useWallhaven = false;
        wallhavenQuery = "";
        wallhavenSorting = "relevance";
        wallhavenOrder = "desc";
        wallhavenCategories = "111";
        wallhavenPurity = "100";
        wallhavenRatios = "";
        wallhavenApiKey = "";
        wallhavenResolutionMode = "atleast";
        wallhavenResolutionWidth = "";
        wallhavenResolutionHeight = "";
        sortOrder = "name";
        favorites = [ ];
      };
      hooks = {
        enabled = true;
        wallpaperChange = "${stylixSyncHook}/bin/noctalia-stylix-sync";
        darkModeChange = "";
        screenLock = "";
        screenUnlock = "";
        performanceModeEnabled = "";
        performanceModeDisabled = "";
        startup = "";
        session = "";
        colorGeneration = "";
      };

    };
  };

  # Tell Stylix to look at that specific file
  stylix.image = ../../assets/current-wallpaper.png;
  # I hate nixos for touching this color file so much.
  xdg.configFile."noctalia/colors.json".enable = false;
  # Seed the configuration
  home.activation.seedNoctaliaShellCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    DEST="$HOME/.config/quickshell/noctalia-shell"
    SRC="${configDir}"

    if [ ! -d "$DEST" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/quickshell"
      $DRY_RUN_CMD cp -R "$SRC" "$DEST"
    fi
  '';
}
