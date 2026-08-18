{ config, lib, vars, inputs, pkgs, ... }:
{
  imports = [
    # disko module: provides the `disko` option + generates fileSystems/swapDevices
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ./host-packages.nix
    ./zfs.nix
  ];

  networking.hostId = "8425e349";

  # Initrd kernel modules for mounting /boot (FAT32)
  boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" ];

  # Post-boot static IPs via NetworkManager
  networking.networkmanager.ensureProfiles.profiles =
    vars.networking.staticProfiles or {};

  # Per-host server service config.
  # These options are always declared (modules/server) and only take effect when
  # the matching vars.serverModules entry is non-null. Values survive while the
  # service is disabled so it can be re-enabled without re-typing them.

  # Pterodactyl panel (reserved 192.168.2.3). Disabled via serverModules.pterodactyl.
  # VPN/LAN-only: the Cloudflare tunnel is OFF and minecraft.bnuy.dev is a grey
  # Minecraft hostname (not the panel), so the only public surface left for
  # this box is mc/minecraft/bnuy.dev:25565 + vpn.bnuy.dev:8443 (headscale).
  # Admin access is via LAN (https://192.168.2.3) or the tailnet subnet router.
  services.pterodactyl = {
    listenIP = "192.168.2.3";
    # APP_URL / LAN domain vhost: step-ca cert covers both pterodactyl.network
    # and 192.168.2.3, so the panel is reachable at either URL without warnings.
    domain = "pterodactyl.network";
    email = "enigma558@proton.me";
    httpsPort = 8443;
    urlPort = 443;
    # No public exposure: web UIs live behind the VPN. With this off the module
    # skips the ACME/domain vhosts entirely; only the LAN vhost is generated.
    cloudflared.enable = false;
    # Old auto-DNS (resolve *.hostname.local) is superseded by the technitium
    # .network zone, which already has a pterodactyl A record for this box.
    configureDNS = false;
  };

  # Technitium DNS (serves home LAN via rack router 192.168.2.2).
  # Disabled via serverModules.technitium.
  # Local zone "network": pterodactyl/minecraft/mailcow/technitium/vpn.network
  # are A records for this box (provisioned declaratively by the
  # technitium-provision service). singularity itself resolves through it too.
  services.technitium = {
    listenAddress = "192.168.2.3";
    useLocally = true;
    localDomain = "network";
    localNames = [ "pterodactyl" "minecraft" "mailcow" "technitium" "vpn" ];
    # vpn.bnuy.dev -> 192.168.2.3 for LAN clients, so the headscale control
    # URL works on WiFi despite the router's no-hairpin NAT.
    # mc.bnuy.dev/minecraft.bnuy.dev -> 192.168.2.3 too, so LAN players can
    # join by name. bnuy.dev itself is deliberately absent: it's a mail apex
    # (MX/DKIM/SPF), and a local Primary zone would shadow those records.
    splitDns = [ "vpn.bnuy.dev" "mc.bnuy.dev" "minecraft.bnuy.dev" ];
  };

  # Tailscale control plane + DERP are at vpn.bnuy.dev:8443. DNS resolves it
  # to the public IP, which this LAN's router can't hairpin back, so pin the
  # LAN IP in /etc/hosts for this box (tailscaled honors it).
  networking.hosts."192.168.2.3" = [ "vpn.bnuy.dev" ];

  # Netboot (LAN-only, never leaves the rack). Enabled via serverModules.netboot.
  services.netboot = {
    listenIp = "192.168.2.3";
    interface = "enp3s0";
  };

  # Headscale VPN server (control plane + exit node + subnet router).
  # Enabled via serverModules.vpn-server.
  #  - Public FQDN vpn.bnuy.dev -> Cloudflare Tunnel -> nginx (LE cert) ->
  #    headscale on 127.0.0.1:8080. DERP relay + STUN ride the same vhost.
  #  - This host is also a tailscale subnet router advertising both LAN
  #    subnets, so remote staff/guest/admin devices reach the panel/mail at
  #    their real LAN IPs (192.168.2.3).
  #  - SOPS secrets (modules/server/vpn/secrets.yaml) MUST exist first:
  #      vpn/cloudflared_token      (dashboard tunnel token)
  #      vpn/admin_preauthkey       (headscale preauthkeys create --user admin
  #                                  --reusable --tags tag:admin)
  services.vpn-server = {
    # 8080 is taken by the pterodactyl Wings API; the nginx vhost proxies to
    # this port automatically.
    port = 8081;
    tunnel = {
      domain = "vpn.bnuy.dev";
      # Dedicated cloudflared for vpn.bnuy.dev (own tunnel, own token in
      # sops vpn/cloudflared_token). Ingress is configured in the Zero Trust
      # dashboard for that tunnel.
      cloudflared = true;
    };
    acl = {
      adminSubnets = [ "192.168.1.0/24" "192.168.2.0/24" ];
      serviceHost = "192.168.2.3";
      # 25565 = Minecraft: tailnet players (staff) connect straight to the box,
      # skipping the Cloudflare relay for lower latency.
      staffPorts = [ 443 993 995 465 587 4190 53 25565 ];
      guestPorts = [ 443 53 ];
    };
    subnetRouter = {
      enable = true;
      routes = [ "192.168.1.0/24" "192.168.2.0/24" ];
      hostname = "singularity";
    };
  };

  # Minecraft WAN = direct grey-cloud DNS + router port-forward (free plan; the
  # Cloudflare tunnel can't carry vanilla MC, TCP public hostnames need client
  # cloudflared). Minecraft is non-HTTP so the edge must NOT proxy it: only the
  # intended hosts (bnuy.dev, mc.bnuy.dev, minecraft.bnuy.dev) get DNS-only A
  # records pointing at the home WAN IP. Explicitly NO wildcard: it would make
  # every unconfigured subdomain (play.bnuy.dev, …) resolve to :25565. The
  # router forwards TCP 25565 -> 192.168.2.3. This service reverts accidental
  # re-proxy/edits on every boot.
  systemd.services.mc-wan-dns = {
    description = "Minecraft: ensure grey-cloud WAN DNS records";
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 30;
    };
    script = ''
      set -eu
      TOKEN=$(cat ${config.sops.secrets."vpn/cf_dns_token".path})
      ZONE=8c9053cc3e915513991733b115055402
      ensure() {
        local name=$1 type=$2 content=$3 proxied=$4
        # Delete any existing record for this name (any type) so a later type
        # switch (e.g. a test CNAME -> the grey A) can't conflict.
        for id in $(curl -sf -H "Authorization: Bearer $TOKEN" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?name=$name" \
          | jq -r '.result[].id'); do
          curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \
            "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/$id" >/dev/null || true
        done
        curl -sf -X POST -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
          -d "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied,\"ttl\":1}" >/dev/null
      }
      ensure bnuy.dev A 70.22.183.131 false
      ensure mc.bnuy.dev A 70.22.183.131 false
      ensure minecraft.bnuy.dev A 70.22.183.131 false
      # No wildcard: delete it if someone re-adds it (play/vpn/etc. would
      # otherwise all point at :25565).
      for id in $(curl -sf -H "Authorization: Bearer $TOKEN" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?type=A&name=*.bnuy.dev" \
        | jq -r '.result[].id'); do
        curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/$id" >/dev/null || true
      done
    '';
  };

  # Remote unlock via initrd SSH. Enabled via serverModules.remoteUnlock.
  services.remoteUnlock = {
    enable = true;
    hostKeys = [ /etc/secrets/initrd/ssh_host_ed25519_key ];
    authorizedKeys = [
      ''command="systemctl default" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNohenCiYWNpZXB05tskL/aP3aYWYtmO8PTz2INP0Up''
    ];
  };

  # Static IPs for both NICs in initrd
  boot.initrd.systemd.network = {
    enable = vars.initrdUnlock.enable or false;
    networks = vars.initrdUnlock.networks or {};
  };

  users.users.admin.initialPassword = "password";
}
