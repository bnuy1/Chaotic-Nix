{
  # Valid: "zen", "xanmod", "stable", "lts"
  kernel = "stable";

  timeZone = "America/New_York";

  users = [
    {
      name = "bnuy";

      isNormalUser = true;
      description = "Mal";
      extraGroups = [
        "networkmanager"
        "wheel"
        "realtime"
      ];
      shell = "fish";
      sshKeys = [ ];

      homeDirectory = null;
      minimal = false;
      nixvimConfig = null;

      extraPkgs = [ ];

      gitUsername = "bnuy1";
      githubSSHKey = "~/.ssh/id_ed25519_github";
      gitEmail = "bnuy@bnuy.dev";
    }
    {
      name = "raina";

      isNormalUser = true;
      description = null;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = "bash";
      sshKeys = [ ];

      homeDirectory = null;
      minimal = false;
      nixvimConfig = null;
      extraPkgs = [ "tmux" ];

      shellAliases = {
        ls = "ls -a --color";
      };

      gitUsername = "Indigo-69";
      githubSSHKey = null;
      gitEmail = "wyfi08g@users.noreply.github.com";
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
  hibernateEnable = false;
  printEnable = true;
  canonPrinterSupport = false;
  fileManager = "dolphin";
  autoUpgradeDates = "weekly";
  autoUpgradeAllowReboot = false;
  gcPeriod = "weekly";
  gcOptions = "--delete-older-than 30d";

  dockerEnable = true;
  podmanEnable = false;
  libvirtdEnable = true;
  virt-managerEnable = false;

  sshPort = 2222;
  bluetoothEnable = true;

  systemFont = "iosevka";
  locale = "en_US.UTF-8";
  NonNixBinarySupport = true;

  gpuDrivers = [ "amd" ];
  rocmEnable = true;
  nvidiaPowerManagement = false;
  powerManagementUtility = "power-profiles-daemon";

  steamEnable = true;
  sunshineEnable = true;

  btrfs = {
    compress = "zstd"; # "zstd", "lzo", "zlib", "none"
    mountOptions = [ "noatime" ];
  };

  snapshots = {
    enable = true;
  };

  netboot = {
    enable = true;
    listenIp = "192.168.1.166";
  };
}
