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
