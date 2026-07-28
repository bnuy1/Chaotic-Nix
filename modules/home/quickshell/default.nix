{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.programs.quickshell-ii;

  # Files/dirs that are "user settings" - never overwritten after first copy
  userFiles = [
    "defaults"
    "settings.qml"
    "GlobalStates.qml"
    "translations"
    ".qmlformat.ini"
  ];

  # Everything else is "code" - always updated from flake
  codeFiles = [
    "modules"
    "panelFamilies"
    "services"
    "scripts"
    "shell.qml"
    "killDialog.qml"
    "ReloadPopup.qml"
    "welcome.qml"
    "assets"
  ];
in
{
  options.programs.quickshell-ii = {
    enable = lib.mkEnableOption "Quickshell with end4's Illogical Impulse config";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      quickshell
      matugen
      kdePackages.kdialog
      mpvpaper
      ffmpeg
      python3Packages.pillow

      # Qt6 modules required by end4's config
      qt6.qtdeclarative
      qt6.qtpositioning
      qt6.qtquicktimeline
      qt6.qtsensors
      qt6.qtimageformats
      qt6.qt5compat
      kdePackages.kirigami.unwrapped
      kdePackages.syntax-highlighting
    ];

    home.activation.quickshellConfig = lib.mkAfter ''
      QUICKSHELL_DIR="$HOME/.config/quickshell"
      II_DIR="$QUICKSHELL_DIR/ii"
      SOURCE="${inputs.dots-hyprland}/dots/.config/quickshell/ii"
      mkdir -p "$QUICKSHELL_DIR"

      # Remove symlink if present (leftover from old approach)
      if [ -L "$II_DIR" ]; then
        rm -f "$II_DIR"
      fi

      # First-time setup: copy everything
      if [ ! -d "$II_DIR" ]; then
        cp -r "$SOURCE" "$II_DIR"
        chown -R "$(id -u):$(id -g)" "$II_DIR"
        chmod -R u+w "$II_DIR"
        echo "$SOURCE" > "$II_DIR/.nix-store-path"
      # Update code files if source changed
      elif [ "$(cat "$II_DIR/.nix-store-path" 2>/dev/null)" != "$SOURCE" ]; then
        # Sync code files (always update)
        ${lib.concatMapStringsSep "\n" (f: ''
          if [ -e "$SOURCE/${f}" ]; then
            rm -rf "$II_DIR/${f}"
            cp -r "$SOURCE/${f}" "$II_DIR/${f}"
          fi
        '') codeFiles}

        # Ensure user files exist (copy only if missing)
        ${lib.concatMapStringsSep "\n" (f: ''
          if [ ! -e "$II_DIR/${f}" ] && [ -e "$SOURCE/${f}" ]; then
            cp -r "$SOURCE/${f}" "$II_DIR/${f}"
          fi
        '') userFiles}

        chown -R "$(id -u):$(id -g)" "$II_DIR"
        chmod -R u+w "$II_DIR"
        echo "$SOURCE" > "$II_DIR/.nix-store-path"
      fi

      # Make scripts executable
      chmod +x "$II_DIR/scripts/"* 2>/dev/null || true

      # Copy shapes submodule (git submodule not fetched by nix, separate flake input)
      SHAPES_DIR="$II_DIR/modules/common/widgets/shapes"
      mkdir -p "$SHAPES_DIR"
      cp -r "${inputs.rounded-polygon}/"* "$SHAPES_DIR/"
      chown -R "$(id -u):$(id -g)" "$SHAPES_DIR"
      chmod -R u+w "$SHAPES_DIR"

      # Always update our wrapper scripts (not part of end4's config)
      rm -f "$QUICKSHELL_DIR/launch.sh" "$QUICKSHELL_DIR/base16-to-m3.py"
      cp ${./launch.sh} "$QUICKSHELL_DIR/launch.sh"
      chmod +x "$QUICKSHELL_DIR/launch.sh"
      cp ${./base16-to-m3.py} "$QUICKSHELL_DIR/base16-to-m3.py"
      chmod +x "$QUICKSHELL_DIR/base16-to-m3.py"

      mkdir -p "$HOME/.local/state/quickshell/user/generated"
    '';
  };
}
