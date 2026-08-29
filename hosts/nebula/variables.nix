{
  # -- System Specific --------------------------------------------------------
  kernel = "stable";

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
      ];

      # Initrd SSH host key for remote LUKS unlock (filename in ~/.ssh/)
      # If set, enables SSH in initrd so you can type LUKS passphrase remotely.
      # All declared keys across all users are accepted; missing files generate warnings.
      remoteLuksDecryptionKeyPath = null; # e.g. "id_ed25519_initrd"            (default: null)

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
  displayManager = "ly-graphical";

  # -- Keyboard / Locale ------------------------------------------------------
  keyboardLayout = "us";
  keyboardVariant = ""; # e.g. "dvorak", "colemak"
  consoleKeyMap = "us"; # Console keymap                                    (default: "us")

  # -- Style / Theming --------------------------------------------------------
  defaultBackgroundImage = ../../assets/wallpapers/sun_moon.jpg; # Wallpaper for stylix
  stylixPolarity = "dark"; # "dark" or "light"                              (default: "dark")

  # -- Browser / Editor -------------------------------------------------------
  # Valid: "librewolf", "firefox", "chromium", "google-chrome", or null
  # Sets $BROWSER session var. google-chrome also enables unfree.
  browser = "librewolf";

  # Trust the bnuy LAN CA root so browsers accept step-ca-issued leaf certs.
  trustBnuyCA = true;

  # Sets $EDITOR, $VISUAL, $SUDO_EDITOR for all users
  editor = "nvim";

  # -- Clock ------------------------------------------------------------------
  # System Clock (waybar, loginManager, etc)
  clock24h = false; # 24-hour clock format

  # -- Power Management -------------------------------------------------------
  suspendEnable = true; # Enable suspend target + lid switch
  hibernateEnable = true; # Enable hibernate + 8GB swapfile

  # Valid: "power-profiles-daemon", "tlp", or null
  powerManagementUtility = "tlp";

  # -- Printing ---------------------------------------------------------------
  printEnable = true; # CUPS + avahi + ipp-usb
  canonPrinterSupport = true; # Install cnijfilter2 Canon printer driver   (default: false)

  # -- File Manager -----------------------------------------------------------
  # Valid: "dolphin", "thunar", or null (no file manager)
  fileManager = "dolphin";

  # -- Gaming -----------------------------------------------------------------
  steamEnable = true; # Steam + gamescope + gamemode + MangoHud
  sunshineEnable = false; # Game streaming server (port 47990)

  # -- Virtualisation ---------------------------------------------------------
  dockerEnable = false; # Rootless Docker daemon + lazydocker
  podmanEnable = false; # Podman container runtime
  libvirtdEnable = false; # KVM/QEMU libvirtd daemon
  virtManagerEnable = false; # GUI VM manager

  # -- Networking -------------------------------------------------------------
  sshPort = 22; # SSH daemon port                                           (default: 22)
  bluetoothEnable = true; # Bluetooth hardware support                     (default: true)
  rsyncPort = null; # SSH port for rsync backup tunnel                      (default: null)

  # -- System -----------------------------------------------------------------
  systemFont = "iosevka-bin"; # System monospace font                          (default: "iosevka")
  locale = "en_US.UTF-8"; # System locale                                  (default: "en_US.UTF-8")
  nonNixBinarySupport = true; # nix-ld: run non-Nix binaries               (default: true)

  # GPU Drivers
  # Valid: any combination of "intel", "amd", "nvidia"
  #
  # Run this to see what to put in the box:
  #   lspci | grep -iE '(vga|3d)' | grep -ioE 'amd|nvidia|intel' | sort -u \
  #     | awk 'BEGIN{printf "["} {printf " \"%s\"", tolower($1)} END{printf " ]\n"}'
  # Example output: [ ]
  gpuDrivers = [
    "intel"
    "nvidia"
  ]; # Catch-all: empty = modesetting only, pick GPU(s) per-host
  rocmEnable = false; # Machine learning optimizations for AMD cards
  nvidiaPowerManagement = true; # NVIDIA power management for Optimus       (default: false)

  # -- Maintenance ------------------------------------------------------------
  # Auto-Upgrade
  autoUpgradeDates = "weekly"; # upgrade is synonomous with update weirdly  (default: "weekly")
  autoUpgradeAllowReboot = false; # Allow auto-reboot after upgrade/update

  # Nix Garbage Collection
  gcPeriod = "weekly"; # do somthing sane                                   (default: "weekly")
  gcOptions = "--delete-older-than 30d"; # Args for nix-collect-garbage      (default: "--delete-older-than 30d")

  # -- Storage ----------------------------------------------------------------
  # Btrfs (set per-host on btrfs systems)
  btrfs = {
    compress = "zstd"; # "zstd", "lzo", "zlib", "none"
    mountOptions = [ "noatime" ];
  };

  snapshots = {
    enable = true;
  };

  # -- Server Modules ---------------------------------------------------------
  # Identical options + comments on every host; only the values differ.
  #   null    = disabled (options stay declared; per-host config lives in default.nix)
  #   true    = enabled with default options
  #   attrset = enabled with those options applied to services.<name>
  # Rule: singularity runs every server service (it's the rack server); every
  # other device is only a headscale VPN client (services.vpn).
  serverModules = {
    pterodactyl = null;   # Pterodactyl game panel
    step-ca = null;       # Step-CA internal certificate authority
    vpn = true;           # headscale VPN client (join the bnuy tailnet)
    vpn-server = null;    # headscale VPN server: control plane + exit node + subnet router
    technitium = null;    # Technitium DNS server
    netboot = null;       # PXE netboot server (iPXE/Kexec)
    remoteUnlock = null;  # initrd SSH remote unlock
    syncthing = null;     # Syncthing file sync
    mailcow = null;       # mailcow mail server
    vaultwarden = null;   # Vaultwarden password manager (VPN-only, split DNS)
    cloudflareDns = null; # dynamic Cloudflare WAN-DNS reconciler
  };
}
