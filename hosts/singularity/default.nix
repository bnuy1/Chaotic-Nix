{ config, lib, vars, inputs, ... }:
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
  # Public access: Cloudflare Tunnel (outbound-only from the server), so the
  # edge router's managed 443 rule and HSTS preload no longer matter.
  #  - Cloudflare zone: bnuy.dev; minecraft.bnuy.dev -> tunnel (CNAME
  #    minecraft.bnuy.dev.cfargotunnel.com, proxied).
  #  - Tunnel ingress: HTTPS -> localhost:443, Origin Server Name
  #    minecraft.bnuy.dev (panel serves the Let's Encrypt cert on 443/8443).
  #  - Direct/LAN access still works at https://minecraft.bnuy.dev:8443 and
  #    port 443 (LE cert via ACME).
  services.pterodactyl = {
    listenIP = "192.168.2.3";
    domain = "minecraft.bnuy.dev";
    email = "enigma558@proton.me";
    httpsPort = 8443;
    # Clean URL through Cloudflare: APP_URL/redirects use https://minecraft.bnuy.dev.
    urlPort = 443;
    # Cloudflare Tunnel daemon. Token must exist in the SOPS secret
    # "pterodactyl/cloudflared_token" (under pterodactyl.cloudflared_token in
    # /etc/nixos/modules/server/pterodactyl/secrets.yaml) BEFORE rebuilding.
    cloudflared.enable = true;
  };

  # Technitium DNS (serves home LAN via rack router 192.168.2.2).
  # Disabled via serverModules.technitium.
  services.technitium.listenAddress = "192.168.2.3";

  # Netboot (LAN-only, never leaves the rack). Disabled via serverModules.netboot.
  services.netboot = {
    listenIp = "192.168.2.4";
    interface = "enp0s31f6";
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
      staffPorts = [ 443 993 995 465 587 4190 ];
      guestPorts = [ 443 ];
    };
    subnetRouter = {
      enable = true;
      routes = [ "192.168.1.0/24" "192.168.2.0/24" ];
      hostname = "singularity";
    };
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
