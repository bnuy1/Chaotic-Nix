# Runtime-managed spicetify for Spotify with live recolor.
#
# Instead of the spicetify-nix home-manager module (which bakes an immutable
# spiced app into the Nix store and cannot be recolored at runtime), this runs
# spicetify-cli against a writable copy of the Spotify app in ~/.local/share.
# The theme (quickshell-m3, generated from the quickshell palette by
# apply-app-themes.sh) is applied at activation and re-refreshed live on every
# palette change via the `recolor` extension (see ./spicetify/recolor.js).
{ dm, inputs, lib, pkgs, ... }:

lib.mkIf dm.graphical (let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  spotifyStore = pkgs.spotify;
  spotifyBin = "${spotifyStore}/bin/spotify";
  spicetifyBin = "${pkgs.spicetify-cli}/bin/spicetify";
  appDir = "$HOME/.local/share/spotify";
  recolorJs = ./spicetify/recolor.js;

  extDefs = [
    spicePkgs.extensions.adblockify
    spicePkgs.extensions.hidePodcasts
    spicePkgs.extensions.shuffle
  ];
  appDefs = [
    spicePkgs.apps.newReleases
    spicePkgs.apps.ncsVisualizer
  ];

  mkExt = e: { "spicetify/Extensions/${e.name}".source = "${e.src}/${e.name}"; };
  extensions = map mkExt extDefs;

  customApps = builtins.listToAttrs (map (a: {
    name = "spicetify/CustomApps/${a.name}";
    value.source = a.src;
  }) appDefs);

  extensionList = "adblock.js|hidePodcasts.js|shuffle+.js|recolor.js";
  customAppList = "new-releases|ncs-visualizer";

  # Everything that affects the applied app; used to skip the expensive
  # restore/backup/apply cycle on unchanged activations.
  sourceFingerprint = lib.concatStringsSep "|" (
    (map (e: "${e.src}/${e.name}") extDefs)
    ++ (map (a: a.src) appDefs)
    ++ [ recolorJs ]
  );
  fingerprint = builtins.hashString "sha256" (
    "${spotifyStore}|${extensionList}|${customAppList}|quickshell-m3|${sourceFingerprint}"
  );

  spotifyLauncher = pkgs.runCommand "spotify" { } ''
    mkdir -p $out/bin $out/share/applications
    cp -r ${spotifyStore}/share/icons $out/share/icons
    cat > $out/bin/spotify <<EOF
#!${pkgs.bash}/bin/bash
# Run the writable spicetify-patched copy of the Spotify app with the same
# environment the store wrapper would use.
eval "\$(head -n -1 '${spotifyBin}')"
exec -a "\$0" "\$HOME/.local/share/spotify/.spotify-wrapped" "\$@"
EOF
    chmod +x $out/bin/spotify
    cp ${spotifyStore}/share/applications/spotify.desktop $out/share/applications/spotify.desktop
  '';
in {
  home.packages = [
    pkgs.spicetify-cli
    spotifyLauncher
  ];

  # Note: xdg.configFile (not home.file) so these land in ~/.config/spicetify,
  # which is where the CLI reads extensions and custom apps from.
  xdg.configFile = lib.mkMerge (extensions ++ [
    customApps
    {
      "spicetify/Extensions/recolor.js".source = recolorJs;
    }
  ]);

  home.activation.deploySpicetify = lib.hm.dag.entryAfter [ "quickshellConfig" ] ''
    export XDG_CONFIG_HOME="$HOME/.config"
    APP_DIR="${appDir}"
    MARKER="$HOME/.local/state/spotify-app-marker"
    WANT="${spotifyStore}:${fingerprint}"
    mkdir -p "$APP_DIR" "$HOME/.config/spotify" "$HOME/.local/state"
    touch "$HOME/.config/spotify/prefs"

    # Keep spicetify config in sync with Nix on every activation (cheap).
    '${spicetifyBin}' config spotify_path "$APP_DIR" >/dev/null 2>&1 || true
    '${spicetifyBin}' config prefs_path "$HOME/.config/spotify/prefs" >/dev/null 2>&1 || true
    '${spicetifyBin}' config current_theme quickshell-m3 color_scheme Base >/dev/null 2>&1 || true
    '${spicetifyBin}' config extensions "${extensionList}" >/dev/null 2>&1 || true
    '${spicetifyBin}' config custom_apps "${customAppList}" >/dev/null 2>&1 || true

    # (Re)build the writable app copy only when the store path changed.
    if [ ! -f "$MARKER" ] || [ "$(cat "$MARKER" 2>/dev/null)" != "$WANT" ]; then
      rm -rf "$APP_DIR"
      cp -r "${spotifyStore}/share/spotify" "$APP_DIR"
      chmod -R u+w "$APP_DIR"
      '${spicetifyBin}' clear >/dev/null 2>&1 || true
      '${spicetifyBin}' -n backup >/dev/null 2>&1 || true
      '${spicetifyBin}' -n apply >/dev/null 2>&1 || true
      printf '%s' "$WANT" > "$MARKER"
    fi
  '';
})
