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
  };

  # Technitium DNS (serves home LAN via rack router 192.168.2.2).
  # Disabled via serverModules.technitium.
  # Local zone "network": pterodactyl/minecraft/mailcow/technitium/vpn/password.network
  # are A records for this box (provisioned declaratively by the
  # technitium-provision service). singularity itself resolves through it too.
  services.technitium = {
    listenAddress = "192.168.2.3";
    useLocally = true;
    localDomain = "network";
    localNames = [ "pterodactyl" "minecraft" "mailcow" "technitium" "vpn" "password" ];
    # vpn.bnuy.dev -> 192.168.2.3 for LAN clients, so the headscale control
    # URL works on WiFi despite the router's no-hairpin NAT.
    # mc/minecraft.bnuy.dev -> same, so LAN players can join by name.
    # password.bnuy.dev -> same, so LAN clients reach the vaultwarden vhost
    # without hairpinning (public A record + LE exist; see vaultwarden module).
    # dash.bnuy.dev -> same, the homepage vhost is public but the box can't
    # hairpin its own WAN IP, so LAN clients resolve it to the LAN IP.
    # kuma.bnuy.dev -> same, uptime-kuma is public.
    # mail.bnuy.dev + mx.bnuy.dev -> same, so LAN roundcube/webmail and LAN
    # mail clients (SMTP/IMAP via mx) don't hairpin through the tunnel/grey A.
    splitDns = [
      "vpn.bnuy.dev"
      "mc.bnuy.dev"
      "minecraft.bnuy.dev"
      "password.bnuy.dev"
      "dash.bnuy.dev"
      "kuma.bnuy.dev"
      "ntfy.bnuy.dev"
      "mail.bnuy.dev"
      "mx.bnuy.dev"
    ];
  };

  # Tailscale control plane + DERP are at vpn.bnuy.dev:8443. DNS resolves it
  # to the public IP, which this LAN's router can't hairpin back, so pin the
  # LAN IP in /etc/hosts for this box (tailscaled honors it).
  networking.hosts."192.168.2.3" = [ "vpn.bnuy.dev" ];
  # Local mailcow: SMTP/IMAP clients (msmtp, vaultwarden, pterodactyl) submit on
  # 587 to this very box. They connect via mail.bnuy.dev so the TLS cert (SAN:
  # mail.bnuy.dev) validates, but resolve it to loopback to stay on-box.
  networking.hosts."127.0.0.1" = [ "mail.bnuy.dev" ];

  # Netboot (LAN-only, never leaves the rack). Enabled via serverModules.netboot.
  services.netboot = {
    listenIp = "192.168.2.3";
    interface = "enp3s0";
  };

  # Vaultwarden: mailcow GAL is the identity source — reconcile the user list
  # against the active mailcow mailboxes hourly (invite missing, disable
  # removed). Signups stay closed; new people join by being added to mailcow.
  # Auth is the /admin cookie flow using the RAW vaultwarden/admin_raw_token
  # secret (the argon2 hash in admin_token only backs the daemon login check).
  # See vaultwarden/CHANGES.md (P-b).
  services.vaultwarden.mailcowSync = true;

  # Public-vhost rate limiting (AGENTS.md P-j): every tunneled request arrives
  # from 127.0.0.1, so key the zone on the CF-supplied client IP (spoof-proof —
  # the edge overrides it) and fall back to the peer for direct LAN hits.
  services.nginx.commonHttpConfig = ''
    limit_req_zone $bnuy_rate_key zone=bnuy_public:10m rate=10r/s;
    map $http_cf_connecting_ip $bnuy_rate_key {
      default $http_cf_connecting_ip;
      "" $binary_remote_addr;
    }
  '';

  # Homepage dashboard (public landing page). Enabled via
  # serverModules.homepage-dashboard. The vhost + cert pipeline live in the
  # module (lib.mkTlsApp); dash.bnuy.dev is a grey-cloud A record + Technitium
  # split-DNS entry so the domain works on LAN without hairpin.
  services.homepage-dashboard.domain = "dash.bnuy.dev";

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
      # 443 only: view-only web for friends. Port 53 dropped so guests can't
      # query Technitium and enumerate internal zones (AGENTS.md G); their
      # devices fall back to their own resolver.
      guestPorts = [ 443 ];
    };
    subnetRouter = {
      enable = true;
      routes = [ "192.168.1.0/24" "192.168.2.0/24" ];
      hostname = "singularity";
    };
  };

  # WAN DNS (grey-cloud A records tracking the rotating home IP) moved to the
  # cloudflareDns server module — see serverModules.cloudflareDns in
  # variables.nix. Same reconciler logic as the old mc-wan-dns service, now
  # reusable by any host, with its own SOPS token
  # (modules/server/cloudflare-dns/secrets.yaml).

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

  # ---------------------------------------------------------------------------
  # System mail (local-only): msmtp submits to the host mailcow on 587 as the
  # singularity@bnuy.dev mailbox. Used by ZFS ZED (drive failure / scrub done),
  # cron and root. Recipients are @bnuy.dev inboxes; nothing leaves the box.
  # ---------------------------------------------------------------------------
  services.mail.sendmailSetuidWrapper.enable = true;

  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = "/etc/aliases";
      port = 587;
      auth = "plain";
      tls = "on";
      tls_starttls = "on";
      tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
    };
    accounts.default = {
      host = "mail.bnuy.dev";
      passwordeval = "cat ${config.sops.secrets."system/msmtp".path}";
      user = "singularity@bnuy.dev";
      from = "singularity@bnuy.dev";
    };
  };

  environment.etc.aliases.text = ''
    root: singularity@bnuy.dev
  '';

  # sops secret for the msmtp password (host-level file; pterodactyl owns the
  # sops.defaultSopsFile for this host, so sopsFile is set explicitly).
  sops.secrets."system/msmtp" = {
    sopsFile = ./secrets.yaml;
    mode = "0400";
  };

  # ZFS Event Daemon: email on drive fault / scrub / resilver / state change.
  # Requires the sendmail setuid wrapper above.
  services.zfs.zed = {
    enableMail = true;
    settings = {
      ZED_EMAIL_ADDR = [ "root" ]; # aliased -> singularity@bnuy.dev
      # notify on succeessful scrub + healthy state changes, not just failures
      ZED_NOTIFY_VERBOSE = true;
    };
  };
}
