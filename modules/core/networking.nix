{ pkgs, ... }:

{
  # Disable wait-online service for faster boot
  systemd.services.NetworkManager-wait-online.enable = false;

  # Enable networking
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    nameservers = [ "9.9.9.11" ];
  };

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    # Force all DNS traffic to be encrypted using TLS
    dnsovertls = "true";
    # Use TLS when possible, but fallback to unencrypted
    #dnsovertls = "opportunistic";
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
    trustedInterfaces = [ "wlp6s0" ]; # Qualcomm Wi-Fi interface
  };

  services.openssh = {
    enable = true;
    ports = [ 5432 ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [
        "raina"
        "fur3"
      ];
    };
  };
  # Open ports in the firewall.           ssh
  networking.firewall.allowedTCPPorts = [ 5432 ];
  networking.firewall.allowedUDPPorts = [
    5432
    47998
    47999
    48000
    48002
  ];

}
