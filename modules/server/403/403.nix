# 403 landing page (services."403").
#
# Operator-authored "access denied" page shown whenever a client that is NOT on
# the LAN/tailnet hits a fenced service - e.g. https://vpn.bnuy.dev/ from the
# public internet when the panel only exists on internal DNS. nginx renders
# THIS page (error_page 403) instead of its default 403 body. No real app,
# service, or admin surface is ever reachable through it (AGENTS posture 5).
#
# The original asset was SCSS; it is hand-flattened to plain CSS here so there
# is no sass build dependency. darken(#F76B1C, 20%) == #C65616 (rgb*0.8).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services."403";
in
{
  options.services."403" = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Provide the shared 403 landing assets (css/html/js)";
    };

    assetsDir = lib.mkOption {
      type = lib.types.path;
      internal = true;
      description = "Store path holding 403.css/403.html/403.js (derived internally)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assets live at one store dir; fenced vhosts mount it and serve the three
    # leaves. Stored as a linkForest (runCommand) so nginx `root` resolves all
    # three. The files are tracked here (403.css/html/js) as plain sources --
    # NOT inline `''...''` Nix strings, whose `''` escaping mangles `content: '';`.
    services."403".assetsDir = pkgs.runCommand "fence403-assets" { } ''
      mkdir -p $out
      ln -s ${./403.css} $out/403.css
      ln -s ${./403.html} $out/403.html
      ln -s ${./403.js} $out/403.js
    '';
  };
}
