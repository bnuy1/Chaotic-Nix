{
  kernel = "xanmod";

  users = [
    {
      name = "fur3";
      gitUsername = "Ha2k4r";
      gitEmail = "bnuy@bnuy.dev";
    }
  ];

  # Used by stylix
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png;

  # Set Display Manager
  # `tui` for Text login
  # `sddm` for graphical GUI (default)
  displayManager = "sddm";

  # Enable/disable bundled applications
  tmuxEnable = false;
  weztermEnable = false;
  ghosttyEnable = false;
  # Note: This is evil-helix with VIM keybindings by default
  helixEnable = false;
  # To install: Enable here, zcli rebuild, then run zcli doom install
  doomEmacsEnable = false;

  # Hyprland Settings
  # Examples:
  # extraMonitorSettings = "monitor = Virtual-1,1920x1080@60,auto,1";
  # extraMonitorSettings = "monitor = HDMI-A-1,1920x1080@60,auto,1";
  # You can configure multiple monitors.
  # Inside the quotes, create a new line for each monitor.
  extraMonitorSettings = "";

  # Waybar Settings (used when barChoice = "waybar")
  clock24h = false;

  browser = "librewolf";

  suspendEnable = true;
  hibernateEnable = true;

  keyboardLayout = "us";
  keyboardVariant = "";
  consoleKeyMap = "us";

  # Enable NFS
  enableNFS = false;

  # Enable Printing Support
  printEnable = true;

  # Enable Thunar GUI File Manager
  # Dolphin is default File Manager
  thunarEnable = false;

  # Auto-upgrade: never auto-reboot a running system
  autoUpgradeAllowReboot = false;

  # Garbage collection (more aggressive for unattended)
  gcPeriod = "weekly";
  gcOptions = "--delete-older-than 30d";

  # Virtualisation / containers
  dockerEnable = false;
  podmanEnable = false;
  libvirtdEnable = false;
  virt-managerEnable = false;

  # Gaming / streaming
  steamEnable = true;
  sunshineEnable = false;

  # Default editor
  editor = "nvim";

  timeZone = "America/New_York";
}
