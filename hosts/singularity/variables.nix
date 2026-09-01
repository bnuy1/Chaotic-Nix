{
  # -- System Specific --------------------------------------------------------
  kernel = "stable";

  secureBoot = false; # Singularity motherboard does not support UEFI Secure Boot

  timeZone = "America/New_York";

  # -- Users ------------------------------------------------------------------
  # Each entry becomes a NixOS user + home-manager config.
  # note: Admin account exists in case home manager fails (which often happens)
  # it is located in /etc/nixos/modules/core/system.nix for emergencys if nothing else.
  users = [
    {
      name = "bnuy";

      # System-level
      isNormalUser = true; # Normal User rather than a service account        (default: true)
      description = "Mal"; # Full Name (optional)                             (default: null)
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = "fish"; # Login shell. Supported: "bash", "fish"                (default: "bash")
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGAEcER9ynK7Fc34QKLC1441KIj4AJh6Ey6W6O6FW8S"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNohenCiYWNpZXB05tskL/aP3aYWYtmO8PTz2INP0Up"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOxWpppGJ3ZCS/HPTS+kxnxdmHqL+HcRG20I197zYxO nebula@bnuy"
      ];

      # Home-manager
      homeDirectory = null; # Custom home dir, null = /home/<name>             (default: null)
      minimal = false; # Skip ../home import (no common pkgs/stylix/etc)      (default: false)
      nixvimConfig = null; # Override auto {user}.nix detection               (default: null)

      # User-specific packages
      # Dot-supported: "kdePackages.kate" and "cowsay" are bolth valid
      extraPkgs = [ ];

      # Per-user shell alias overrides (merged on top of systemAliases)
      shellAliases = { };

      # Git glorious development
      gitUsername = "bnuy1";
      githubSSHKey = "~/.ssh/id_ed25519_github"; # Dedicated SSH key for GitHub (default: null)
      gitEmail = "bnuy@bnuy.dev";
    }
  ];

  # -- Display ----------------------------------------------------------------
  # Valid: "sddm", "sddm-graphical", "sddm-headless",
  #        "tui",  "tui-headless",   "tui-graphical",
  #        "ly",   "ly-headless",    "ly-graphical"
  displayManager = "tui-headless";

  # -- Keyboard / Locale ------------------------------------------------------
  keyboardLayout = "us";
  keyboardVariant = ""; # e.g. "dvorak", "colemak"
  consoleKeyMap = "us"; # Console keymap                                    (default: "us")

  # -- Style / Theming --------------------------------------------------------
  defaultBackgroundImage = ../../assets/wallpapers/Stocking.png; # Wallpaper for stylix
  stylixPolarity = "dark"; # "dark" or "light"                              (default: "dark")

  # -- Browser / Editor -------------------------------------------------------
  # Valid: "librewolf", "firefox", "chromium", "google-chrome", or null
  # Sets $BROWSER session var. google-chrome also enables unfree.
  browser = null;

  # step-ca-issued CA leaf certs.
  trustBnuyCA = true;

  # Sets $EDITOR, $VISUAL, $SUDO_EDITOR for all users
  editor = "nvim";

  # -- Clock ------------------------------------------------------------------
  # System Clock (waybar, loginManager, etc)
  clock24h = true; # 24-hour clock format

  # -- Power Management -------------------------------------------------------
  suspendEnable = false; # Enable suspend target + lid switch
  hibernateEnable = false; # Enable hibernate + 8GB swapfile

  # Valid: "power-profiles-daemon", "tlp", or null
  powerManagementUtility = null;

  # -- Printing ---------------------------------------------------------------
  printEnable = false; # CUPS + avahi + ipp-usb
  canonPrinterSupport = false; # Install cnijfilter2 Canon printer driver   (default: false)

  # -- File Manager -----------------------------------------------------------
  # Valid: "dolphin", "thunar", or null (no file manager)
  fileManager = null;

  # -- Gaming -----------------------------------------------------------------
  steamEnable = false; # Steam + gamescope + gamemode + MangoHud
  sunshineEnable = false; # Game streaming server (port 47990)

  # -- Virtualisation ---------------------------------------------------------
  dockerEnable = true; # Rootless Docker daemon + lazydocker
  podmanEnable = false; # Podman container runtime
  libvirtdEnable = false; # KVM/QEMU libvirtd daemon
  virtManagerEnable = false; # GUI VM manager

  # -- Networking -------------------------------------------------------------
  sshPort = 2222; # SSH daemon port, same as initrd unlock port              (default: 22)
  bluetoothEnable = false; # Bluetooth hardware support                    (default: true)
  rsyncPort = 39127; # SSH port for rsync backup tunnel                    (default: null)

  networking.staticProfiles = {
    "enp3s0" = {
      connection = {
        id = "enp3s0";
        type = "ethernet";
      };
      ipv4 = {
        # DHCP from rack router 192.168.2.2 (reserved 192.168.2.3)
        method = "auto";
      };
    };
    "enp0s31f6" = {
      connection = {
        id = "enp0s31f6";
        type = "ethernet";
      };
      ipv4 = {
        # DHCP from rack router 192.168.2.2 (reserved 192.168.2.4, netboot interface)
        method = "auto";
      };
    };
  };

  # Initrd Remote Unlock
  # SSH into port 2222, enter passphrases, system boots
  # Static pre-DHCP addresses so unlock works regardless of reservations.
  initrdUnlock = {
    enable = true;
    networks = {
      "10-enp3s0" = {
        matchConfig.Name = "enp3s0";
        address = [ "192.168.2.3/24" ];
        routes = [ { Gateway = "192.168.2.2"; } ];
        linkConfig.RequiredForOnline = "routable";
      };
      "10-enp0s31f6" = {
        matchConfig.Name = "enp0s31f6";
        address = [ "192.168.2.4/24" ];
        routes = [ { Gateway = "192.168.2.2"; } ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # -- System -----------------------------------------------------------------
  systemFont = "iosevka-bin"; # System monospace font                          (default: "iosevka")
  locale = "en_US.UTF-8"; # System locale                                  (default: "en_US.UTF-8")
  nonNixBinarySupport = false; # nix-ld: run non-Nix binaries              (default: true)

  # GPU Drivers
  # Valid: any combination of "intel", "amd", "nvidia"
  #
  # Run this to see what to put in the box:
  #   lspci | grep -iE '(vga|3d)' | grep -ioE 'amd|nvidia|intel' | sort -u \
  #     | awk 'BEGIN{printf "["} {printf " \"%s\"", tolower($1)} END{printf " ]\n"}'
  # Example output: [ ]
  gpuDrivers = [ ]; # Catch-all: empty = modesetting only, pick GPU(s) per-host
  rocmEnable = false; # Machine learning optimizations for AMD cards
  nvidiaPowerManagement = false; # NVIDIA power management for Optimus      (default: false)

  # -- Maintenance ------------------------------------------------------------
  # Auto-Upgrade
  autoUpgradeDates = "weekly"; # upgrade is synonomous with update weirdly  (default: "weekly")
  autoUpgradeAllowReboot = false; # Allow auto-reboot after upgrade/update

  # Nix Garbage Collection
  gcPeriod = "daily"; # do somthing sane                                    (default: "weekly")
  gcOptions = "--keep-generations 12"; # Args for nix-collect-garbage        (default: "--delete-older-than 30d")

  # -- Storage ----------------------------------------------------------------
  # Swap
  swap = { };

  # ZFS
  zfs = {
    compress = "zstd";
  };

  snapshots = {
    enable = true;
  };

  # -- Server Modules ---------------------------------------------------------
  # Identical options + comments on every host; only the values differ.
  #   null    = disabled (options stay declared; per-host config lives in default.nix)
  #   true    = enabled with default options
  #   attrset = enabled with those options applied to services.<name>
  serverModules = {
    pterodactyl = {
      mcAdmin = true;
    }; # Pterodactyl game panel + bnuy-* commands
    step-ca = true; # Step-CA internal certificate authority
    vpn = null; # headscale VPN client (join the bnuy tailnet)
    vpn-server = true; # headscale VPN server: control plane + exit node + subnet router
    technitium = true; # Technitium DNS server
    netboot = true; # PXE netboot server (iPXE/Kexec)
    remoteUnlock = true; # initrd SSH remote unlock
    syncthing = true; # Syncthing file sync
    mailcow = true; # mailcow mail server
    vaultwarden = true; # Vaultwarden password manager (VPN-only, split DNS)
    homepage-dashboard = true; # Homepage dashboard (public: dash.bnuy.dev)
    uptime-kuma = true; # Uptime Kuma (public: kuma.bnuy.dev)
    ntfy-sh = true; # ntfy push notifications (public: ntfy.bnuy.dev)
    # authentik SSO/IdP (public at auth.bnuy.dev, tunneled): identity + nginx
    # forward-auth for no-native-login apps (headscale panel, homepage mgmt).
    authentik = true;
    # Cloudflare tunnel (outbound) fronting every public web hostname - the ISP
    # blocks inbound 443, so web exits via the CF edge (dash/kuma/ntfy/password
    # web UI + mail.bnuy.dev roundcube/admin + auth.bnuy.dev SSO). LE flips to
    # DNS-01 for these.
    cloudflare-tunnel = {
      hosts = [
        "dash.bnuy.dev"
        "kuma.bnuy.dev"
        "ntfy.bnuy.dev"
        "password.bnuy.dev"
        "mail.bnuy.dev"
        "auth.bnuy.dev"
      ];
    };
    # Grey-cloud A records that must track the rotating WAN IP (see
    # hosts/singularity/default.nix history: 2026-08-23 WAN rotation took down
    # remote VPN + would have reverted mail/MC DNS). Everything tunneled is EXCLUDED
    # here - the reconciler force-substitutes grey As and would clobber the CF
    # proxied CNAMEs the tunnel needs. mx.bnuy.dev is the direct mail-protocols
    # host (MX/SMTP/IMAP), split from the tunneled mail.bnuy.dev web UI.
    cloudflareDns = {
      zoneId = "8c9053cc3e915513991733b115055402";
      records = [
        "bnuy.dev"
        "mx.bnuy.dev"
        "mc.bnuy.dev"
        "minecraft.bnuy.dev"
        "vpn.bnuy.dev"
      ];
      purgeWildcardName = "*.bnuy.dev";
    };
    # Operator 403 landing page for fenced services (services."403"). Fence
    # vhosts (vpn panel, technitium panel, the 443 default stub) serve its
    # assets when a non-LAN/tailnet client trips a deny.
    "403" = true;
  };
}
