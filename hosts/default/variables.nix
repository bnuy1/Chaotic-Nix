{
  # -- System Specific --------------------------------------------------------
  # Valid: "zen", "xanmod", "stable", "lts"
  kernel = "stable";

  timeZone = "America/New_York";

  # -- Users ------------------------------------------------------------------
  # Each entry becomes a NixOS user + home-manager config.
  # note: Admin account exists in case home manager fails (which often happens)
  # it is located in /etc/nixos/modules/core/system.nix for emergencys if nothing else.
  users = [
    {
      name = "bnuy"; # Login name (Unix username)

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
    {
      name = "raina";

      # System-level
      isNormalUser = true; # Normal User rather than a service account        (default: true)
      description = null; # Full Name (optional)                              (default: null)
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = "bash"; # Login shell. Supported: "bash", "fish"                (default: "bash")
      sshKeys = [
      ];

      # Initrd SSH host key for remote LUKS unlock (filename in ~/.ssh/)
      # If set, enables SSH in initrd so you can type LUKS passphrase remotely.
      # All declared keys across all users are accepted; missing files generate warnings.
      remoteLuksDecryptionKeyPath = null; # e.g. "id_ed25519_initrd"            (default: null)

      # Home-manager
      homeDirectory = ""; # Empty = no home directory created                   (default: null)
      minimal = true; # Skip ../home import (no common pkgs/stylix/etc)       (default: false)
      nixvimConfig = null; # Override auto {user}.nix detection               (default: null)

      # User-specific packages, This was difficult to make this supports pretty much everything including dots
      # Dot-supported: "kdePackages.kate" and "cowsay" are bolth valid
      extraPkgs = [ "tmux" ]; # raina wants tmux, bnuy does not

      # Per-user shell alias overrides (merged on top of systemAliases)
      shellAliases = { };

      # Git glorious development
      gitUsername = "Indigo-69";
      githubSSHKey = null; # Dedicated SSH key for GitHub (default: null)
      gitEmail = "wyfi08g@users.noreply.github.com";
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
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png; # Wallpaper for stylix
  stylixPolarity = "dark"; # "dark" or "light"                              (default: "dark")

  # -- Browser / Editor -------------------------------------------------------
  # Valid: "librewolf", "firefox", "chromium", "google-chrome", or null
  # Sets $BROWSER session var. google-chrome also enables unfree.
  browser = "firefox";

  # Sets $EDITOR, $VISUAL, $SUDO_EDITOR for all users
  editor = "nvim";

  # -- Clock ------------------------------------------------------------------
  # System Clock (waybar, loginManager, etc)
  clock24h = false; # 24-hour clock format

  # -- Power Management -------------------------------------------------------
  suspendEnable = true; # Enable suspend target + lid switch
  hibernateEnable = false; # Enable hibernate + 8GB swapfile

  # Valid: "power-profiles-daemon", "tlp", or null
  powerManagementUtility = "power-profiles-daemon"; # (default: "power-profiles-daemon")

  # -- Printing ---------------------------------------------------------------
  printEnable = true; # CUPS + avahi + ipp-usb
  canonPrinterSupport = false; # Install cnijfilter2 Canon printer driver   (default: false)

  # -- File Manager -----------------------------------------------------------
  # Valid: "dolphin", "thunar", or null (no file manager)
  fileManager = "dolphin";

  # -- Gaming -----------------------------------------------------------------
  steamEnable = false; # Steam + gamescope + gamemode + MangoHud
  sunshineEnable = false; # Game streaming server (port 47990)

  # -- Virtualisation ---------------------------------------------------------
  dockerEnable = true; # Rootless Docker daemon + lazydocker
  podmanEnable = false; # Podman container runtime
  libvirtdEnable = false; # KVM/QEMU libvirtd daemon
  virt-managerEnable = false; # GUI VM manager

  # -- Networking -------------------------------------------------------------
  sshPort = 2222; # SSH daemon port                                        (default: 2222)
  bluetoothEnable = true; # Bluetooth hardware support                     (default: true)

  # -- System -----------------------------------------------------------------
  systemFont = "iosevka"; # System monospace font                          (default: "iosevka")
  locale = "en_US.UTF-8"; # System locale                                  (default: "en_US.UTF-8")
  NonNixBinarySupport = true; # nix-ld: run non-Nix binaries               (default: true)

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
  gcOptions = "--delete-older-than 7d"; # Args for nix-collect-garbage      (default: "--delete-older-than 30d")

  # -- Storage ----------------------------------------------------------------
  # Btrfs (set per-host on btrfs systems)
  btrfs = { };

  # Swap
  swap = {
    enable = true; # zram swap
    zramPercent = 100; # % of RAM for zram
    algorithm = "zstd"; # zram compression
    swapFileSize = 8192; # MB when hibernateEnable = true
    luksSwapUuid = null; # UUID of LUKS-encrypted swap partition              (default: null)
  };

  # Snapshots
  snapshots = {
    enable = true;
    schedule = "hourly"; # systemd OnCalendar or short name
    exclude = [ "/nix" ];

    retention = {
      hourly = null; # null -> default (24)
      daily = null; # null -> default (7)
      weekly = null; # null -> default (4)
      monthly = null; # null -> default (6)
      yearly = null; # null -> default (0)
    };
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
