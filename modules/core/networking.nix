{ pkgs, vars, lib, ... }:

{
  systemd.services.NetworkManager-wait-online.enable = false;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    nameservers = [ "1.1.1.1" ];
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "opportunistic";
      DNSSEC = "true";
      Domains = [ "~." ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy.AutoEnable = true;
    };
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wlp6s0" ];
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
