{ vars, dm, config, inputs, pkgs, lib, ... }:

let
  # end-4 upstream hyprland/ config (deployed as a writable copy, overwritten every build)
  hyprlandSource = "${inputs.dots-hyprland}/dots/.config/hypr/hyprland";

  # custom/ seed files (written once at activation, then preserved for runtime edits)
  customSeed = pkgs.runCommand "hypr-custom" { } ''
    mkdir -p "$out/scripts"
    cp ${./custom/env.lua} "$out/env.lua"
    cp ${./custom/execs.lua} "$out/execs.lua"
    cp ${./custom/general.lua} "$out/general.lua"
    cp ${./custom/variables.lua} "$out/variables.lua"
    cp ${./rules.lua} "$out/rules.lua"
    cp ${./custom/end4-keybinds.lua} "$out/end4-keybinds.lua"
    cp ${./custom/keybinds.lua} "$out/keybinds.lua"
    cp ${./custom/scripts/__restore_video_wallpaper.sh} "$out/scripts/__restore_video_wallpaper.sh"
    chmod +x "$out/scripts/__restore_video_wallpaper.sh"
  '';

  # qs wrapper: replicate launch.sh env so end-4's `qs -c $qsConfig` works
  qsWrapper = pkgs.writeShellScript "qs-wrapper" ''
    for profile in "$HOME/.nix-profile" "/etc/profiles/per-user/$USER" "/run/current-system/sw"; do
      resolved="$(readlink -f "$profile" 2>/dev/null || echo "$profile")"
      schema_dir="$resolved/share/gsettings-schemas"
      if [ -d "$schema_dir" ]; then
        for schema in "$schema_dir"/*; do
          if [ -d "$schema" ] && [[ ":$XDG_DATA_DIRS:" != *":$schema:"* ]]; then
            XDG_DATA_DIRS="''${XDG_DATA_DIRS:+$XDG_DATA_DIRS:}$schema"
          fi
        done
      fi
    done
    export XDG_DATA_DIRS
    export QS_ICON_THEME=hicolor
    export ILLOGICAL_IMPULSE_VIRTUAL_ENV="$HOME/.local/state/quickshell/.venv"
    exec "/etc/profiles/per-user/$USER/bin/qs" "$@"
  '';
in
{
  imports = [
    ../quickshell
  ];

  wayland.windowManager.hyprland = {
    enable = dm.graphical;
    xwayland.enable = true;
    configType = "lua";
  };

  # qs wrapper must shadow the quickshell package's qs in the session PATH
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  xdg.configFile = {
    # Nix-managed entry point (overwritten every build)
    "hypr/hyprland.lua".source = ./hyprland.lua;

    # Hypridle stays as hyprlang (hybrid approach)
    "hypr/hypridle.conf".source = ./hypridle.conf;

    # Other configs
    "hypr/hyprsunset.conf".source = ./hyprsunset.conf;

    # Scripts
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };

    # end-4's hyprlock (read-only; not the primary lock screen)
    "hypr/hyprlock.conf".source = "${inputs.dots-hyprland}/dots/.config/hypr/hyprlock.conf";
    "hypr/hyprlock" = {
      source = "${inputs.dots-hyprland}/dots/.config/hypr/hyprlock";
      recursive = true;
    };
  };

  home.activation.deployHyprland = lib.mkIf dm.graphical (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_DIR="$HOME/.config/hypr"
    HYPR_LAND="$HYPR_DIR/hyprland"
    mkdir -p "$HYPR_DIR"

    # 1. end-4 hyprland/ dir: content-synced from the store, never deleted.
    #    Rule: missing -> create; contents differ -> single write; identical -> untouched.
    #    shellOverrides/main.lua is owned by the shell at runtime - skipped, never synced.
    mkdir -p "$HYPR_LAND/shellOverrides"
    while IFS= read -r f; do
      rel="''${f#"${hyprlandSource}"}"
      case "$rel" in
        /shellOverrides/main.lua) continue ;;
      esac
      dst="$HYPR_LAND$rel"
      if [ ! -e "$dst" ] || ! cmp -s "$f" "$dst"; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$f" "$dst"
        # store sources are read-only (cp preserves mode) - make the copy editable
        chmod u+rw "$dst"
      fi
    done < <(find "${hyprlandSource}" -type f)

    # 2. Seed custom/ once; afterwards these files are user-owned
    CUSTOM_DIR="$HYPR_DIR/custom"
    mkdir -p "$CUSTOM_DIR/scripts"
    ${lib.concatStringsSep "\n" (map (name: ''
      if [ ! -f "$CUSTOM_DIR/${name}" ]; then
        cp -p "${customSeed}/${name}" "$CUSTOM_DIR/${name}"
      fi
    '') [ "env.lua" "execs.lua" "general.lua" "rules.lua" "variables.lua" "end4-keybinds.lua" "keybinds.lua" ])}
    if [ ! -f "$CUSTOM_DIR/scripts/__restore_video_wallpaper.sh" ]; then
      cp -p "${customSeed}/scripts/__restore_video_wallpaper.sh" "$CUSTOM_DIR/scripts/__restore_video_wallpaper.sh"
    fi
    # store copies arrive read-only (cp preserves mode) - custom/ is user-editable
    chmod -R u+rwX "$CUSTOM_DIR"

    # 3. Remove stale flat module files (pre-end-4 layout)
    for f in appearance autostart binds rules lib profiles; do
      if [ -L "$HYPR_DIR/$f.lua" ]; then
        rm -f "$HYPR_DIR/$f.lua"
      fi
    done

    # 4. qs wrapper on PATH (home.sessionPath) - replicates launch.sh env
    mkdir -p "$HOME/.local/bin"
    cp -f "${qsWrapper}" "$HOME/.local/bin/qs"
    chmod +x "$HOME/.local/bin/qs"
  '');

  # Lid + battery policy for the locked session (graphical only)
  systemd.user.services.lockdown = lib.mkIf dm.graphical {
    unitConfig = {
      Description = "Lockdown: lid and locked-session battery policy";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      WantedBy = [ "graphical-session.target" ];
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${config.xdg.configFile."hypr/scripts".source}/lockdown.sh";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
