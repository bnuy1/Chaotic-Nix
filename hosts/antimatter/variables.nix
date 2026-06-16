{
  kernel = "zen";

  users = [
    {
      name = "fur3";
      description = "Mal";
      gitUsername = "bnuy1";
      gitEmail = "bnuy@bnuy.dev";
    }
    {
      name = "raina";
      gitUsername = "Indigo-69";
      gitEmail = "wyfi08g@users.noreply.github.com";
    }
  ];

  # Used by stylix
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png;

  # Set Display Manager
  # `tui` for Text login and no graphical system
  # `sddm` for graphical GUI (default)
  displayManager = "sddm";

  clock24h = false;
  # firefox, librewolf whatever else you prefer.
  browser = "librewolf";

  suspendEnable = true;
  hibernateEnable = false;

  keyboardLayout = "us";
  keyboardVariant = "";
  consoleKeyMap = "us";

  # Enable NFS
  enableNFS = true;

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
  dockerEnable = true;
  podmanEnable = false;
  libvirtdEnable = true;
  virt-managerEnable = false;

  # Gaming / streaming
  steamEnable = true;
  sunshineEnable = true;

  # Default editor
  editor = "nvim";

  timeZone = "America/New_York";
}
