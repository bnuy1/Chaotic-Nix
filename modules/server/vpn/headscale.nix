# headscale coordination server for the bnuy tailnet (services.vpn-server).
#
# This is the *server* module (control plane + DERP + exit node + subnet
# router). Client nodes join the tailnet via ./client.nix (services.vpn).
# Served on 127.0.0.1:8080 by the nixpkgs headscale module; nginx terminates
# TLS (public Let's Encrypt cert for <domain>) and proxies through. The
# Cloudflare tunnel cannot carry TS2021 (cloudflared strips the Upgrade header
# on POST, cloudflare/cloudflared#883), so headscale is exposed on
# <domain>:<publicPort> via a router port-forward. singularity also runs a
# tailscale subnet router advertising
# the LAN subnets, so remote staff/guest/admin devices can reach the panel and
# mail at their real LAN IPs.
#
# Access tiers (Tailscale ACL policy, HuJSON generated from `services.vpn-server.acl`):
#   bnuy@ / admin@ / tag:admin -> everything (all nodes, all ports, incl. SSH)
#   staff@                     -> the mail/panel ports on the service host + internet via exit node
#   guest@                     -> only HTTPS on the service host (view-only, app must require login)
# Users map to tailnet access; tags exist only for the box itself (tag:admin) and
# netboot. Only admins may assign tags (tagOwners). The subnet-router routes and
# the exit-node route are auto-approved for tag:admin.
#
# Internet egress: singularity advertises as an exit node; only tiers listed in
# the `internet:*` rule (bnuy/admin/staff) may route traffic through it. guest
# gets no such rule, so it cannot use the box to reach the internet — and a
# device's own LTE/WiFi egress is outside the tailnet's control entirely.
#
# Visibility vs interaction: the tailnet peer list shows every node to every
# user, but ACLs gate interaction, so staff/guest see singularity + admin's
# devices yet can only reach the ports singularity exposes to them.

{ config, lib, pkgs, ... }:

let
  hs = config.services.vpn-server;
  tailscale = config.services.tailscale;

  domain = hs.tunnel.domain;

  # Tailscale/headscale ACL policy in HuJSON (JSON is valid HuJSON).
  aclJson = builtins.toJSON {
    # headscale 0.29's policy parser only accepts owners of the form
    # user@, group:..., or tag:... (no autogroup, no bare names). A local
    # user `admin` is referenced as `admin@` (trailing @ stripped on match).
    tagOwners = {
      "tag:admin" = [ "admin@" ];
      "tag:staff" = [ "admin@" ];
      "tag:guest" = [ "admin@" ];
      "tag:netboot" = [ "admin@" ];
    };
    acls = [
      {
        action = "accept";
        src = [ "bnuy@" "admin@" "tag:admin" ];
        dst = [ "*:*" ];
      }
      {
        action = "accept";
        src = [ "staff@" ];
        dst = map (port: "${hs.acl.serviceHost}:${toString port}") hs.acl.staffPorts;
      }
      {
        action = "accept";
        src = [ "guest@" ];
        dst = map (port: "${hs.acl.serviceHost}:${toString port}") hs.acl.guestPorts;
      }
      # Internet egress via singularity as an exit node: everyone except guest.
      # autogroup:internet grants routing through any approved exit node.
      {
        action = "accept";
        src = [ "bnuy@" "admin@" "staff@" ];
        dst = [ "autogroup:internet:*" ];
      }
    ];
    autoApprovers = {
      # Subnet routes auto-approve for tag:admin (singularity) only; employees
      # can never hold tag:admin (tagOwners = admin@), so they can't get a
      # route approved this way. Exit-node routes are deliberately NOT
      # auto-approved: no employee node should ever become an exit node, so
      # the box's 0.0.0.0/0 is approved manually once.
      routes = lib.genAttrs hs.acl.adminSubnets (_: [ "tag:admin" ]);
    };
  };
  aclFile = pkgs.writeText "headscale-acl.hujson" aclJson;
in
{
  options.services.vpn-server = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the headscale VPN server (control plane, exit node, subnet router)";
    };

    # The actual headscale daemon is delegated to nixpkgs' services.headscale
    # module (systemd unit, user/dataDir); these three options mirror the ones
    # we use from it so hosts configure this module, not nixpkgs' directly.
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Listening port of headscale (proxied by nginx)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.headscale;
      description = "headscale package to run";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Overrides passed straight to services.headscale.settings (headscale config.yaml)";
    };

    tunnel = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "vpn.bnuy.dev";
        description = "Public FQDN for the headscale control plane + DERP";
      };
      # cloudflared strips the non-websocket Upgrade header that TS2021 needs,
      # so the tunnel can't serve headscale. Instead expose it on a high port
      # (ISP blocks inbound 80/443) through a router port-forward.
      publicPort = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "Public port the control plane + DERP are served on";
      };
      # Cloudflare Tunnel daemon. If enabled, the "vpn/cloudflared_token"
      # SOPS secret must exist BEFORE rebuilding.
      cloudflared = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run cloudflared to expose the nginx vhost via a Cloudflare Tunnel";
      };
    };

    acl = {
      adminSubnets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "192.168.1.0/24" "192.168.2.0/24" ];
        description = "LAN subnets admin-tagged nodes may reach (also advertised by the subnet router)";
      };
      serviceHost = lib.mkOption {
        type = lib.types.str;
        default = "192.168.2.3";
        description = "LAN IP of the mail/panel host that staff + guest may reach";
      };
      staffPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 443 993 995 465 587 4190 ];
        description = "Ports staff may reach on the service host (panel/webmail, IMAPS, SMTPS/submission, POP3S, sieve)";
      };
      guestPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 443 ];
        description = "Ports guest may reach on the service host (view-only web access)";
      };
    };

    # Turn singularity itself into a tailscale subnet router so remote clients
    # can reach LAN IPs (e.g. 192.168.2.3) directly.
    subnetRouter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run a tailscale client on this host advertising the LAN subnets";
      };
      routes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = hs.acl.adminSubnets;
        description = "Subnets to advertise (must match acl.adminSubnets for auto-approval)";
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "singularity";
        description = "Tailnet hostname for this node";
      };
    };
  };

  config = lib.mkIf hs.enable {
    # Delegate the daemon (systemd service, user/dataDir) to nixpkgs' headscale
    # module; this module only drives it.
    services.headscale = {
      enable = true;
      port = hs.port;
      package = hs.package;
      settings = hs.settings;
    };

    services.vpn-server.settings = {
      server_url = "https://${domain}:${toString hs.tunnel.publicPort}";

      dns = {
        magic_dns = true;
        base_domain = "hs.bnuy.dev";
        override_local_dns = false;
        nameservers.global = [ ];
      };

      # Self-hosted relay: only our embedded DERP region, no public tailscale
      # DERP maps. STUN on UDP 3478 so direct peering works when possible.
      derp = {
        urls = [ ];
        paths = [ ];
        auto_update_enabled = false;
        server = {
          enabled = true;
          region_id = 999;
          region_code = "bnuy";
          region_name = "bnuy";
          stun_listen_addr = "0.0.0.0:3478";
          verify_clients = true;
          automatically_add_embedded_derp_region = true;
        };
      };

      policy = {
        mode = "file";
        path = aclFile;
      };
    };

    # tailscale/headscale only honours X-Forwarded-For from trusted proxies.
    services.vpn-server.settings.trusted_proxies = [ "127.0.0.1/32" ];

    services.nginx = {
      enable = lib.mkDefault true;
      virtualHosts.${domain} = {
        serverName = domain;
        addSSL = true;
        enableACME = true;
        http2 = true;
        listen = [
          { addr = "0.0.0.0"; port = 443; ssl = true; }
          { addr = "0.0.0.0"; port = hs.tunnel.publicPort; ssl = true; }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString hs.port}";
          proxyWebsockets = true;
          # Long timeout: DERP relay keeps a WebSocket open for the connection's lifetime.
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };
      # The Cloudflare tunnel exposes the http://localhost:80 leg (TLS is
      # terminated at the Cloudflare edge), so this vhost proxies headscale
      # instead of redirecting to https.
      virtualHosts."${domain}-http" = {
        serverName = domain;
        listen = [
          { addr = "0.0.0.0"; port = 80; }
        ];
        useACMEHost = domain;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString hs.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };

      # headscale-admin GUI: tailnet-only (bound to the tailscale IP), so it is
      # never reachable from the LAN/WAN. ACLs already keep staff/guest away
      # from singularity entirely. The static UI is behind nginx basic auth
      # (password in SOPS), which also stops admin@, whose *:* rule would
      # otherwise reach it — headscale's policy has no `deny` action, so the
      # password is the bnuy-only gate. /api/ is deliberately NOT basic-auth'd:
      # the app's Bearer API key must survive to headscale, and a browser only
      # sends one Authorization header, so basic auth there would break every
      # API call. The API key itself is the admin credential for /api/.
      virtualHosts."headscale-admin" = {
        serverName = "singularity.hs.bnuy.dev";
        listen = [
          { addr = "100.64.0.1"; port = 8444; }
        ];
        locations."/admin" = {
          return = "302 /admin/";
        };
        locations."/admin/" = {
          proxyPass = "http://127.0.0.1:8083";
          basicAuthFile = config.sops.secrets."vpn/headscale_admin_htpasswd".path;
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };
        # Same-origin API: the browser sends its Bearer API key straight
        # through to headscale, avoiding CORS entirely.
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:${toString hs.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
      };
    };

    security.acme = {
      acceptTerms = lib.mkDefault true;
      defaults.email = lib.mkDefault "enigma558@proton.me";
    };

    # DNS-01: the cert must stay renewable without inbound :80 (blocked by the
    # ISP and no longer tunneled since the record is DNS-only). lego verifies
    # ownership via the Cloudflare DNS:Edit token from SOPS.
    security.acme.certs.${domain} = {
      dnsProvider = "cloudflare";
      credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets."vpn/cf_dns_token".path;
      # nginx's enableACME sets a webroot; DNS-01 replaces it (mutually exclusive).
      webroot = lib.mkForce null;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 hs.tunnel.publicPort ];
    networking.firewall.allowedUDPPorts = [ 3478 ];

    # The tunnel Service URL is https://vpn.bnuy.dev:443 so cloudflared
    # verifies the origin cert against the real hostname; pin it to localhost
    # so it dials this nginx instead of looping back into the CF edge.
    networking.extraHosts = lib.mkIf hs.tunnel.cloudflared "127.0.0.1 ${domain}";

    sops.secrets."vpn/cloudflared_token" = lib.mkIf hs.tunnel.cloudflared {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    # Cloudflare API token (DNS:Edit on the bnuy.dev zone) for LE DNS-01.
    sops.secrets."vpn/cf_dns_token" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };

    systemd.services.cloudflared-headscale = lib.mkIf hs.tunnel.cloudflared {
      description = "Cloudflare Tunnel daemon (headscale)";
      after = [
        "network-online.target"
        "sops-nix.service"
        "nginx.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
        # Remotely-managed tunnel: ingress is configured in the Cloudflare
        # Zero Trust dashboard; cloudflared only needs the tunnel token.
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token \"$(cat ${config.sops.secrets."vpn/cloudflared_token".path})\"'";
      };
    };

    # Provision the headscale user namespaces (users = tailnets).
    # Admin then creates tagged pre-auth keys (see secrets.yaml.example).
    systemd.services.vpn-server-provision = {
      description = "Create headscale user namespaces";
      after = [ "headscale.service" ];
      requires = [ "headscale.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for u in bnuy admin staff guest; do
          ${hs.package}/bin/headscale users create "$u" 2>/dev/null || true
        done
      '';
    };

    services.tailscale = lib.mkIf hs.subnetRouter.enable {
      enable = true;
      # Subnet router: enable IP forwarding on this host.
      useRoutingFeatures = "server";
      openFirewall = true;
      # Pre-auth key must be a tagged key created with --tags tag:admin
      # (see secrets.yaml.example) so the node owns/approves its routes.
      authKeyFile = config.sops.secrets."vpn/admin_preauthkey".path;
      extraUpFlags = [
        "--login-server=https://${domain}:${toString hs.tunnel.publicPort}"
        "--hostname=${hs.subnetRouter.hostname}"
        "--advertise-routes=${lib.concatStringsSep "," hs.subnetRouter.routes}"
        # singularity is also the tailnet exit node (staff/admin/bnuy browse the
        # internet through it); the route auto-approves via policy autoApprovers.
        "--advertise-exit-node"
      ];
    };

    # This kernel build (xanmod, security.lockKernelModules) has no xt_mark
    # module, so tailscaled cannot install its own exit-node NAT (the ts-nat
    # chain never gets created; health shows a MARK warning). The CGNAT range
    # is small and fixed, so masquerade it manually on the WAN interface.
    # ponytail: hardcoded CGNAT range, fine while tailscale uses 100.64.0.0/10.
    systemd.services.tailscale-exitnode-nat = lib.mkIf hs.subnetRouter.enable {
      description = "MASQUERADE tailnet egress for the exit node";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        iface=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $5; exit}')
        ${pkgs.iptables}/bin/iptables -t nat -C POSTROUTING -s 100.64.0.0/10 -o "$iface" -j MASQUERADE 2>/dev/null \
          || ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 100.64.0.0/10 -o "$iface" -j MASQUERADE
      '';
    };

    # headscale-admin: static management UI served by nginx above. Image tags
    # track headscale majors; 0.27 is the newest build (works with 0.29's API).
    virtualisation.oci-containers.backend = lib.mkDefault "docker";
    virtualisation.oci-containers.containers.headscale-admin = lib.mkIf hs.enable {
      image = "goodieshq/headscale-admin:v0.27";
      # Host-loopback only; nginx proxies /admin/ to it.
      ports = [ "127.0.0.1:8083:80" ];
    };

    # The subnet router forwards LAN<->tailnet traffic; reverse-path filtering
    # must be loose so replies from LAN hosts to tailnet IPs aren't dropped.
    networking.firewall.checkReversePath = lib.mkIf hs.subnetRouter.enable "loose";

    # tailscaled needs the tun device, but security.lockKernelModules disables
    # runtime module loading; load tun from the initrd (it stays loaded).
    boot.initrd.kernelModules = lib.mkIf hs.subnetRouter.enable [ "tun" ];

    sops.secrets."vpn/admin_preauthkey" = lib.mkIf hs.subnetRouter.enable {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    sops.secrets."vpn/headscale_admin_htpasswd" = lib.mkIf hs.enable {
      sopsFile = ./secrets.yaml;
      group = "nginx";
      mode = "0440";
    };
  };
}
