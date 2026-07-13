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
      initialPassword = "password";
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGAEcER9ynK7Fc34QKLC1441KIj4AJh6Ey6W6O6FW8S"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNohenCiYWNpZXB05tskL/aP3aYWYtmO8PTz2INP0Up"
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

  displayManager = "tui-headless";
  keyboardLayout = "us";
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png;
  stylixPolarity = "dark";

  browser = null;
  editor = "nvim";
  clock24h = true;
  suspendEnable = false;
  hibernateEnable = false;
  printEnable = false;
  canonPrinterSupport = false;
  fileManager = null;
  autoUpgradeDates = "weekly";
  autoUpgradeAllowReboot = false;
  gcPeriod = "daily";
  gcOptions = "--keep-generations 12";

  dockerEnable = true;
  podmanEnable = false;
  libvirtdEnable = false;
  virt-managerEnable = false;

  sshPort = 2222;
  bluetoothEnable = false;

  systemFont = "iosevka";
  locale = "en_US.UTF-8";
  NonNixBinarySupport = false;

  gpuDrivers = [ ];
  rocmEnable = false;
  nvidiaPowerManagement = false;
  powerManagementUtility = null;

  steamEnable = false;
  sunshineEnable = false;

  zfs = {
    compress = "zstd";
  };

  snapshots = {
    enable = true;
  };
}
