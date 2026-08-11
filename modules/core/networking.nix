{
  pkgs,
  vars,
  lib,
  ...
}:

let
  sshPort = vars.sshPort or 22;
  vpnServerEnable = ((vars.serverModules or { }).vpn-server or null) == true;
in
{
  # Disable wait-online service for faster boot
  systemd.services.NetworkManager-wait-online.enable = false;

  # Set IPv4 forwarding explicitly to avoid NM race condition (needed for the
  # headscale exit-node / subnet router on the vpn-server host)
  boot.kernel.sysctl = lib.optionalAttrs vpnServerEnable { "net.ipv4.ip_forward" = 1; };

  # Fixes networking related permissions problems
  users.groups.netdev = { };

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      unmanaged = [ "interface-name:wg*" ];
      # Don't let router RA/DHCP inject DNS — every host resolves via the rack
      # DNS server (Technitium on singularity at 192.168.2.3).
      # mkForce: nixpkgs resolved.nix unconditionally sets
      # dns = "systemd-resolved", which pushes per-link router DNS into resolved.
      dns = lib.mkForce "none";
    };

    enableIPv6 = true;
    # Local DNS: singularity runs Technitium, which validates DNSSEC and
    # recurses to the root servers itself (configurable for DoT/DoH upstream in
    # its web UI). Clients therefore trust the LAN/tailnet leg as cleartext.
    # Off-LAN hosts reach it via the tailnet subnet route (192.168.2.0/24).
    nameservers = [ "192.168.2.3" ];

    # iwd is auto-enabled with sane defaults (DriverQuirks.DefaultInterface="?*")
    # when wifi.backend = "iwd". Do NOT re-add EnableNetworkConfiguration here:
    # iwd doing its own DHCP races NetworkManager (see plan.md).

    useDHCP = false;

  };
  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        # Technitium validates DNSSEC + recurses upstream, so clients trust the
        # LAN/tailnet leg as cleartext (DNSSEC/DNSOverTLS stay at their nixpkgs
        # defaults = false).
        Domains = [ "~." ];
        # Let avahi handle .local mDNS — avoids dual-stack warnings
        MulticastDNS = false;
      };
    };
  };

  hardware.bluetooth = {
    enable = vars.bluetoothEnable or true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ ];
  };

  services.openssh = {
    enable = true;
    ports = [ sshPort ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      # vars.users authenticate with their keys; the fallback `admin` account
      # exists on every host and may also log in (key auth).
      AllowUsers = map (user: user.name) vars.users ++ [ "admin" ];
      MaxAuthTries = 3;
      MaxSessions = 4;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      AllowTcpForwarding = "no";
      X11Forwarding = false;
      LogLevel = "VERBOSE";
    };
  };

  # Open ports in the firewall.           ssh
  networking.firewall.allowedTCPPorts = [
    sshPort
  ]
  ++ lib.optionals (vars.rsyncPort or null != null) [ vars.rsyncPort ];
  networking.firewall.allowedUDPPorts = [ ];

  services.fail2ban = {
    enable = true;
    maxretry = 20;
    bantime = "10m";
    ignoreIP = [
      "127.0.0.1/8"
    ];
  };
}
