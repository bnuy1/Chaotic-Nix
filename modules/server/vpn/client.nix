# headscale client: joins this host to the bnuy tailnet as a plain node.
#
# No routes advertised; all non-tailnet traffic egresses through the exit node
# (singularity, services.vpn-server), which is the single NAT point, so clients
# need no firewall rules or forwarding of their own.
#
# First join needs a one-shot pre-auth key. The box is the only host with an
# age key, so this is deliberately NOT a SOPS secret: create a one-shot key for
# the device's user in the headscale-admin GUI (or `headscale preauthkeys
# create --user <user> --tags tag:admin`), drop it on the host at
# /var/lib/tailscale/preauthkey, then rebuild. tailscaled consumes it once and
# the node's own state file takes over afterwards.

{ config, lib, ... }:

let
  vpn = config.services.vpn;
in
{
  options.services.vpn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Join this host to the bnuy headscale tailnet as a client";
    };

    loginServer = lib.mkOption {
      type = lib.types.str;
      default = "https://vpn.bnuy.dev:8443";
      description = "headscale control plane URL";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Tailnet hostname for this node";
    };

    exitNode = lib.mkOption {
      type = lib.types.str;
      default = "singularity";
      description = "Tailnet node used as the exit node for internet egress";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept subnet routes advertised by the exit node (LAN reachability)";
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a one-shot pre-auth key file (not a SOPS secret; see module header)";
    };

    controlPlaneIP = lib.mkOption {
      type = lib.types.str;
      default = "192.168.2.3";
      description = "LAN IP of the headscale control plane. Pinned in /etc/hosts so vpn.bnuy.dev resolves to it (the edge router has no hairpin NAT, so the public IP is unreachable from the LAN).";
    };
  };

  config = lib.mkIf vpn.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = vpn.authKeyFile;
      extraUpFlags = [
        "--login-server=${vpn.loginServer}"
        "--hostname=${vpn.hostname}"
        "--accept-routes"
        "--exit-node=${vpn.exitNode}"
      ];
    };
    networking.hosts."${vpn.controlPlaneIP}" = [ "vpn.bnuy.dev" ];
  };
}
