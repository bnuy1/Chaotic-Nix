{ config, pkgs, lib, host, vars, ... }:
{
  options.custom.allowUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Package names allowed as unfree via allowUnfreePredicate.";
  };

  config = {
    # Allow unfree packages
    nixpkgs.config.allowUnfree = false;
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) config.custom.allowUnfreePackages;
    # Garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Set your time zone.
    time.timeZone = vars.timeZone;

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      createHome = true;
    };
    # Power Management
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;

    # Kernel hardening
    security.lockKernelModules = true;
    security.protectKernelImage = true;
    boot.kernel.sysctl = {
      "kernel.kptr_restrict" = "2";
      "kernel.dmesg_restrict" = "1";
      "net.core.bpf_jit_harden" = "2";
      "kernel.yama.ptrace_scope" = "2";
    };

    # Automatic system updates
    system.autoUpgrade = {
      enable = true;
      dates = "weekly";
      allowReboot = false;
    };

    # Nix settings
    nix.settings = {
      auto-optimise-store = true;
      min-free = "2G";
      max-free = "10G";
      trusted-users = [ "root" "@wheel" ];
      allowed-users = [ "*" ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    nix.optimise.automatic = true;

    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true

      #media-session.enable = true;
    };
  };
}
