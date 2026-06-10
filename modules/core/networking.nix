{
  pkgs,
  vars,
  lib,
  ...
}:

{
  # Disable wait-online service for faster boot
  systemd.services.NetworkManager-wait-online.enable = false;

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

    enableIPv6 = true;
    nameservers = [ "9.9.9.9" ];
    #nameservers = [ "192.168.1.99" ];

    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };

    useDHCP = false;

  };
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    # Force all DNS traffic to be encrypted using TLS
    #dnsovertls = "true";
    # Use TLS when possible, but fallback to unencrypted
    dnsovertls = "opportunistic";
  };

  hardware.bluetooth = {
    enable = true;
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
    ports = [ 2222 ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ vars.Primary-User ] ++ lib.optionals (vars ? Secondary-User) [ vars.Secondary-User ];
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
  networking.firewall.allowedTCPPorts = [ 5432 ];
  networking.firewall.allowedUDPPorts = [
    2222
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
      "192.168.0.0/24"
    ];
  };
}
