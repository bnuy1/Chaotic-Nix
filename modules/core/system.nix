{ config, pkgs, lib, host, vars, ... }:

let
  defaultLocale = vars.locale or "en_US.UTF-8";
  isHeadless = lib.hasSuffix "-headless" (vars.displayManager or "");
in
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

    nixpkgs.config.permittedInsecurePackages = lib.optionals (!isHeadless) [
      "ventoy-1.1.07" # TODO: bump as needed; nixpkgs will flag this when stale
    ];

    custom.allowUnfreePackages = lib.optionals (vars.browser == "google-chrome" || vars.browser == "chrome") [
      "google-chrome"
    ];
    # Garbage collection
    nix.gc = {
      automatic = true;
      dates = vars.gcPeriod or "weekly";
      options = vars.gcOptions or "--delete-older-than 30d";
    };

    # Set your time zone.
    time.timeZone = vars.timeZone;

    # Select internationalisation properties.
    i18n.defaultLocale = defaultLocale;

    i18n.extraLocaleSettings = {
      LC_ADDRESS = defaultLocale;
      LC_IDENTIFICATION = defaultLocale;
      LC_MEASUREMENT = defaultLocale;
      LC_MONETARY = defaultLocale;
      LC_NAME = defaultLocale;
      LC_NUMERIC = defaultLocale;
      LC_PAPER = defaultLocale;
      LC_TELEPHONE = defaultLocale;
      LC_TIME = defaultLocale;
    };

    system.stateVersion = "25.11";

    # Global distro branding (About screen, neofetch/fastfetch, system tools)
    system.nixos = {
      distroName = "BnuyOS";
      distroId = "bnuyos";
      vendorName = "BnuyOS";
      vendorId = "bnuyos";
      extraOSReleaseArgs = {
        PRETTY_NAME = "BnuyOS V0.6";
        NAME = "BnuyOS";
        ID = "bnuyos";
        ID_LIKE = "nixos";
        VERSION = "V0.6";
        VERSION_ID = "0.6";
        HOME_URL = "https://bnuy.dev";
        VENDOR_URL = "https://bnuy.dev";
        DOCUMENTATION_URL = "https://github.com/bnuy1/bnuynix";
        SUPPORT_URL = "https://github.com/bnuy1/bnuynix";
        BUG_REPORT_URL = "https://github.com/bnuy1/bnuynix/issues";
        PRIVACY_POLICY_URL = "https://github.com/bnuy1/bnuynix";
        LOGO = "nixos-symbolic";
      };
    };

    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      createHome = true;
    };
    # Power Management
    services.power-profiles-daemon.enable = (vars.powerManagementUtility or "power-profiles-daemon") == "power-profiles-daemon";
    services.upower.enable = true;

    # File manager mounting support (USB drives, etc.)
    services.gvfs.enable = !isHeadless;
    services.udisks2.enable = !isHeadless;
    security.polkit.enable = true;
    programs.thunar.enable = (vars.fileManager or null) == "thunar";
    boot.supportedFilesystems = lib.optionals (!isHeadless) [ "exfat" ] ++ lib.optionals (vars.zfs or null != null) [ "zfs" ];
    boot.kernelModules = lib.optionals (!isHeadless) [ "exfat" "isofs" "udf" "usb_storage" "uas" "sd_mod" ];

    services.fstrim.enable = true;

    hardware.enableRedistributableFirmware = !isHeadless;
    hardware.firmware = lib.optionals (!isHeadless) (with pkgs; [
      linux-firmware
    ]);

    # Kernel hardening
    security.lockKernelModules = true;
    security.protectKernelImage = true;
    boot.kernel.sysctl = {
      "kernel.kptr_restrict" = "2";        # hide kernel addresses
      "kernel.dmesg_restrict" = "1";       # only root sees kernel logs
      "net.core.bpf_jit_harden" = "2";     # harden bpf compiler
      "kernel.yama.ptrace_scope" = "2";    # only root can debug other procs

      "net.ipv4.tcp_syncookies" = "1";           # stop syn floods
      "net.ipv4.conf.all.rp_filter" = "1";       # drop spoofed packets
      "net.ipv4.conf.default.rp_filter" = "1";   # same for new ifaces
      "net.ipv4.conf.all.accept_redirects" = "0";  # ignore route hijacks
      "net.ipv4.conf.default.accept_redirects" = "0";
      "net.ipv4.conf.all.secure_redirects" = "0";
      "net.ipv4.conf.default.secure_redirects" = "0";
      "net.ipv6.conf.all.accept_redirects" = "0";
      "net.ipv6.conf.default.accept_redirects" = "0";
      "net.ipv4.conf.all.log_martians" = "1";     # log weird packets
      "net.ipv4.conf.default.log_martians" = "1";
      "net.ipv4.icmp_echo_ignore_broadcasts" = "1";      # ignore ping floods
      "net.ipv4.icmp_ignore_bogus_error_responses" = "1"; # ignore fake errors
    };

    # Automatic system updates
    system.autoUpgrade = {
      enable = vars.autoUpgradeEnable or true;
      dates = vars.autoUpgradeDates or "weekly";
      allowReboot = vars.autoUpgradeAllowReboot or false;
    };

    # Nix settings
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      min-free = "2G";
      max-free = "10G";
      trusted-users = [ "root" "@wheel" ];
      allowed-users = if isHeadless then [ "@wheel" ] else [ "*" ];
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

    programs.fish.enable = true;
    programs.nix-ld.enable = vars.nonNixBinarySupport or true;

    # System fonts
    fonts.packages = [
      (lib.getAttrFromPath (lib.splitString "." (vars.systemFont or "iosevka-bin")) pkgs)
    ];

    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    security.rtkit.enable = !isHeadless;
    services.pipewire = lib.mkIf (!isHeadless) {
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
