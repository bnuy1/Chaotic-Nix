# Cloudflare Tunnel (outbound web egress) - escapes the ISP's inbound :443
# block by having cloudflared dial OUT to the Cloudflare edge, which fronts
# our public hostnames. Same shape as the vpn.bnuy.dev tunnel (headscale),
# generalized to any number of hostnames on the shared nginx.
#
# Why: Verizon blocks inbound 443 (confirmed). Port 80 stays open (proven -
# LE http-01 renews daily), so LE certs for these hostnames switch to DNS-01
# (see lib.nix mkTlsApp acmeDns) and never touch inbound ports again.
# Hostnames here are proxied CNAMEs in the CF zone; the reconciler
# (cloudflareDns.records) must NOT list them or it clobbers those CNAMEs.
#
# How it reaches the origin: each hostname's DNS points at the CF edge, so
# cloudflared must NOT dial the public name (hairpin). The
# cloudflared-tunnel-hosts unit pins every hostname to 127.0.0.1 inside
# cloudflared's PRIVATE /etc/hosts (BindReadOnlyPaths), so the tunnel connects
# to nginx on loopback with the right SNI; nginx serves the app by Host header
# + the matching LE cert.
#
# The tunnel itself is REMOTELY-MANAGED: public hostname -> origin routes are
# configured in the Zero Trust dashboard for this tunnel. cloudflared only
# needs the tunnel token here.
#
# Token lives in the SOPS secrets.yaml (cloudflare-tunnel/token). Until the
# operator fills a real token the unit exits cleanly (skip mode) so a rebuild
# is a no-op, not a crash-loop. No inbound firewall ports needed - outbound
# only. One tunnel = one unit = single point of failure for web, same as the
# single nginx it fronts today.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services."cloudflare-tunnel";
in
{
  options.services."cloudflare-tunnel" = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run a Cloudflare tunnel (outbound) for the listed hostnames";
    };

    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "dash.bnuy.dev"
        "kuma.bnuy.dev"
      ];
      description = ''
        Public hostnames carried by the tunnel. Each one must exist as a
        public hostname in the tunnel's Zero Trust dashboard, routed to
        https://<same-hostname>, and the matching LE cert must use DNS-01
        (http-01 can't pass the edge). The tile pins them to 127.0.0.1 so
        cloudflared's origin dial stays on loopback.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cloudflare-tunnel/token" = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    # Write the loopback pin for each tunnel hostname into a private hosts
    # file ONLY this cloudflared sees (mounted over /etc/hosts below). The
    # public hostnames keep resolving to the CF edge for everyone else.
    # Deliberately NOT the vpn module's cloudflared-hosts service/file: that
    # one pins vpn.bnuy.dev for the headscale cloudflared, and both processes
    # getting the same /etc/hosts overlay would clobber each other's pins.
    systemd.services.cloudflared-tunnel-hosts = {
      description = "Write loopback hosts file for the cloudflared tunnel origin";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        printf '127.0.0.1 localhost\n::1 localhost\n${lib.concatMapStringsSep "\n" (h: "127.0.0.1 ${h}") cfg.hosts}\n' > /run/cloudflared-tunnel-hosts
        chmod 0644 /run/cloudflared-tunnel-hosts
      '';
    };

    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel daemon (${builtins.concatStringsSep ", " cfg.hosts})";
      after = [
        "network-online.target"
        "sops-nix.service"
        "nginx.service"
        "cloudflared-tunnel-hosts.service"
      ];
      requires = [ "cloudflared-tunnel-hosts.service" ];
      wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.cloudflared pkgs.coreutils pkgs.bash ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
        # cloudflared only: the origin dial must see the 127.0.0.1 pins,
        # while everyone else resolves the hostnames to the CF edge.
        BindReadOnlyPaths = [ "/run/cloudflared-tunnel-hosts:/etc/hosts" ];
      };
      script = ''
        set -eu
        TOKEN=$(cat ${config.sops.secrets."cloudflare-tunnel/token".path})
        if [ -z "$TOKEN" ] || [ "$TOKEN" = "CHANGE_ME" ]; then
          echo "cloudflared-tunnel: token not set in sops cloudflare-tunnel/token - idle"
          exit 0
        fi
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token "$TOKEN"
      '';
    };
  };
}