{
  pkgs,
  vars,
  lib,
  ...
}:

let
  sshPort = vars.sshPort or 2222;
in
{
  # Disable wait-online service for faster boot
  systemd.services.NetworkManager-wait-online.enable = false;

  # Set IPv4 forwarding explicitly to avoid NM race condition
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      unmanaged = [ "interface-name:wg*" ];
    };

    enableIPv6 = true;
    nameservers = [
      "9.9.9.9"
      "1.1.1.1"
    ];
    #nameservers = [ "192.168.1.99" ];

    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };

    useDHCP = false;

  };
  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSSEC = "true";
        Domains = [ "~." ];
        # Force all DNS traffic to be encrypted using TLS
        DNSOverTLS = "opportunistic";
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
    trustedInterfaces = [ "wlp6s0" ];
    # Qualcomm Wi-Fi interface was : wlp6s0 before it somehow stopped detecting

  };

  services.openssh = {
    enable = true;
    ports = [ sshPort ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = map (user: user.name) vars.users;
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
  ++ lib.optionals (vars.sunshineEnable or false) [
    47989
    47990
  ]
  ++ lib.optionals (vars.rsyncBackupEnable or false) [ 873 ];
  networking.firewall.allowedUDPPorts = lib.optionals (vars.sunshineEnable or false) [
    47998
    47999
    48000
    48002
  ];

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "127.0.0.1/8"
      "192.168.1.0/24"
    ];
  };
}
