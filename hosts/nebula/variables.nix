{
  kernel = "xanmod";

  timeZone = "America/New_York";

  users = [
    {
      name = "bnuy";

      isNormalUser = true;
      description = "Mal";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = "fish";
      sshKeys = [
      ];

      homeDirectory = null;
      minimal = false;
      nixvimConfig = null;

      extraPkgs = [ ];

      gitUsername = "Ha2k4r";
      githubSSHKey = null;
      gitEmail = "bnuy@bnuy.dev";
    }
  ];

  displayManager = "sddm-graphical";
  keyboardLayout = "us";
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png;
  stylixPolarity = "dark";

  browser = "librewolf";
  editor = "nvim";
  clock24h = false;
  suspendEnable = true;
  hibernateEnable = true;
  printEnable = true;
  canonPrinterSupport = false;
  fileManager = "dolphin";
  autoUpgradeDates = "weekly";
  autoUpgradeAllowReboot = false;
  gcPeriod = "weekly";
  gcOptions = "--delete-older-than 30d";

  dockerEnable = false;
  podmanEnable = false;
  libvirtdEnable = false;
  virt-managerEnable = false;

  sshPort = 2222;
  bluetoothEnable = true;

  grubConfigLimit = 30;
  systemFont = "iosevka";
  locale = "en_US.UTF-8";
  NonNixBinarySupport = true;

  gpuDrivers = [ "intel" "nvidia" ];
  rocmEnable = false;
  nvidiaPowerManagement = true;
  powerManagementUtility = "tlp";

  steamEnable = true;
  sunshineEnable = false;

  btrfs = {
    compress = "zstd"; # "zstd", "lzo", "zlib", "none"
    mountOptions = [ "noatime" ];
  };

  snapshots = {
    enable = true;
  };
}
