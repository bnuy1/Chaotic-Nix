{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.vpn;
in
{
  options.services.vpn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WireGuard VPN server";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "wg0";
      description = "WireGuard interface name";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "UDP port for WireGuard";
    };

    host = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.1/24";
        description = "IP address (with CIDR) for this host on the VPN";
      };

      privateKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to the host's WireGuard private key file";
      };

      privateKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Host WireGuard private key as a string.
          WARNING: this adds the key to the world-readable Nix store.
          Prefer privateKeyFile instead.
        '';
      };
    };

    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Human-readable name for this peer";
          };
          publicKey = lib.mkOption {
            type = lib.types.str;
            description = "Peer's WireGuard public key";
          };
          allowedIPs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "10.0.0.2/32" ];
            description = "IP ranges to route to this peer";
          };
          endpoint = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Peer endpoint (host:port). Null means peer connects to us";
          };
          persistentKeepalive = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = 25;
            description = "Seconds between keepalive pings. Null disables";
          };
        };
      });
      default = [ ];
      description = "WireGuard peers";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host.privateKeyFile != null || cfg.host.privateKey != null;
        message = "services.vpn: must set either host.privateKeyFile or host.privateKey";
      }
      {
        assertion = cfg.host.privateKeyFile == null || cfg.host.privateKey == null;
        message = "services.vpn: set only one of host.privateKeyFile or host.privateKey, not both";
      }
    ];

    boot.kernelModules = [ "wireguard" ];

    environment.systemPackages = [ pkgs.wireguard-tools ];

    systemd.services."vpn-${cfg.interface}" = {
      description = "WireGuard VPN - ${cfg.interface}";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ wireguard-tools iproute2 ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectHome = true;
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        RestrictAddressFamilies = [ "AF_NETLINK" "AF_UNIX" ];
        MemoryDenyWriteExecute = true;
      };
      script = let
        hostKeyArg = if cfg.host.privateKeyFile != null then
          "private-key ${cfg.host.privateKeyFile}"
        else
          "private-key <(echo '${cfg.host.privateKey}')";
      in ''
        set -e
        ${pkgs.iproute2}/bin/ip link add dev ${cfg.interface} type wireguard 2>/dev/null || true

        ${pkgs.wireguard-tools}/bin/wg set ${cfg.interface} \
          ${hostKeyArg} \
          listen-port ${toString cfg.listenPort}

        ${lib.concatMapStringsSep "\n" (peer: ''
          ${pkgs.wireguard-tools}/bin/wg set ${cfg.interface} peer ${peer.publicKey} \
            allowed-ips ${lib.concatStringsSep "," peer.allowedIPs} \
            ${if peer.endpoint != null then "endpoint ${peer.endpoint}" else ""} \
            ${if peer.persistentKeepalive != null then "persistent-keepalive ${toString peer.persistentKeepalive}" else ""}
        '') cfg.peers}

        ${pkgs.iproute2}/bin/ip addr add ${cfg.host.address} dev ${cfg.interface}
        ${pkgs.iproute2}/bin/ip link set up dev ${cfg.interface}
      '';
      preStop = ''
        ${pkgs.iproute2}/bin/ip link del dev ${cfg.interface} 2>/dev/null || true
      '';
    };

    networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
  };
}
