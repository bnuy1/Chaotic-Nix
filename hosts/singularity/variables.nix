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
      initialPassword = "password";
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGAEcER9ynK7Fc34QKLC1441KIj4AJh6Ey6W6O6FW8S"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNohenCiYWNpZXB05tskL/aP3aYWYtmO8PTz2INP0Up"
      ];

      # Initrd SSH host key for remote LUKS unlock (filename in ~/.ssh/)
      # If set, enables SSH in initrd so you can type LUKS passphrase remotely.
      # All declared keys across all users are accepted; missing files generate warnings.
      remoteLuksDecryptionKeyPath = "id_ed25519_initrd"; # e.g. "id_ed25519_initrd" (default: null)

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
  displayManager = "tui-headless";

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
  browser = null;

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
  virt-managerEnable = false; # GUI VM manager

  # -- Networking -------------------------------------------------------------
  sshPort = 2222; # SSH daemon port                                        (default: 2222)
  bluetoothEnable = false; # Bluetooth hardware support                    (default: true)

  # -- System -----------------------------------------------------------------
  systemFont = "iosevka"; # System monospace font                          (default: "iosevka")
  locale = "en_US.UTF-8"; # System locale                                  (default: "en_US.UTF-8")
  NonNixBinarySupport = false; # nix-ld: run non-Nix binaries              (default: true)

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
  swap = {
    luksSwapUuid = "714230b7-3382-4de4-aa51-c8d66f660995"; # UUID of LUKS-encrypted swap partition
  };

  # ZFS
  zfs = {
    compress = "zstd";
  };

  snapshots = {
    enable = true;
  };

  # -- Server Modules ---------------------------------------------------------
  # true = enabled with default config, attrset = enabled with custom config, null = not imported
  serverModules = {
    pterodactyl = true;
    vpn = true;
    technitium = true;
    netboot = {
      listenIp = "192.168.1.166";
    };
  };
}
