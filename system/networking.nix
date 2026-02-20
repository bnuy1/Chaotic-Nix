{ pkgs, ... }:

{ 
  # Disable wait-online service for faster boot
  systemd.services.NetworkManager-wait-online.enable = false;

  # Enable networking
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    # DNS-over-TLS with Mullvad DNS servers with ad and tracker blocking
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
}
