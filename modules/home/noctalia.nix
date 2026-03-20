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

      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/Pictures/wallpapers";
        # ...
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
