{
  # -- System Specific --------------------------------------------------------
  kernel = "xanmod";

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

      # User-specific packages, This was difficult to make this supports pretty much everything including dots
      # Dot-supported: "kdePackages.kate" and "cowsay" are bolth valid
      extraPkgs = [ ];

      # Per-user shell alias overrides (merged on top of systemAliases)
      shellAliases = { };

      # Git glorious development
      gitUsername = "Ha2k4r";
      githubSSHKey = null; # Dedicated SSH key for GitHub (default: null)
      gitEmail = "bnuy@bnuy.dev";
    }
  ];

  # -- Display ----------------------------------------------------------------
  # Valid: "sddm", "sddm-graphical", "sddm-headless",
  #        "tui",  "tui-headless",   "tui-graphical",
  #        "ly",   "ly-headless",    "ly-graphical"
  displayManager = "sddm-graphical";

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
  browser = "librewolf";

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
  canonPrinterSupport = false; # Install cnijfilter2 Canon printer driver   (default: false)

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
  sshPort = 2222; # SSH daemon port                                        (default: 2222)
  bluetoothEnable = true; # Bluetooth hardware support                     (default: true)
  rsyncPort = null; # SSH port for rsync backup tunnel                      (default: null)

  # -- System -----------------------------------------------------------------
  systemFont = "iosevka"; # System monospace font                          (default: "iosevka")
  locale = "en_US.UTF-8"; # System locale                                  (default: "en_US.UTF-8")
  nonNixBinarySupport = true; # nix-ld: run non-Nix binaries               (default: true)

  # GPU Drivers
  # Valid: any combination of "intel", "amd", "nvidia"
  #
  # Run this to see what to put in the box:
  #   lspci | grep -iE '(vga|3d)' | grep -ioE 'amd|nvidia|intel' | sort -u \
  #     | awk 'BEGIN{printf "["} {printf " \"%s\"", tolower($1)} END{printf " ]\n"}'
  # Example output: [ ]
  gpuDrivers = [ "intel" "nvidia" ]; # Catch-all: empty = modesetting only, pick GPU(s) per-host
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
  # true = enabled with default config, attrset = enabled with custom config, null = not imported
  serverModules = {
    pterodactyl = null;
    vpn = null;
    technitium = null;
    netboot = null;
  };
}
