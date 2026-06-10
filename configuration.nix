{
  pkgs,
  lib,
  host,
  networkingHostname,
  vars,
  ...
}:
{
  _module.args.host = host;
  imports = [
    ./modules/core
    ./hosts/${host}
  ]
  ++ lib.optional (builtins.pathExists ./modules/development/t440p/t4.nix) ./modules/development/t440p/t4.nix;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable redistributable firmware (needed for Qualcomm Wi-Fi)
  hardware.enableRedistributableFirmware = true;

  # Ensure firmware package is present
  hardware.firmware = with pkgs; [
    linux-firmware
  ];

  networking.hostName = networkingHostname; # Define your hostname.

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  #XDG_CURRENT_DESKTOP=GNOME element-desktop
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = vars.keyboardLayout;
    variant = vars.keyboardVariant;
  };

  # Gaming optimizations
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;
  hardware.opengl = {
    extraPackages = with pkgs; [ mangohud ];
    extraPackages32 = with pkgs; [ mangohud ];
  };
  # SSD trimming (safe: only issues TRIM to devices that support it)
  services.fstrim.enable = true;

  programs.fish.enable = true;

  programs.nix-ld.enable = true;
  programs.command-not-found.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      # Web UI port
      port = 47990;

      origin_web_ui_allowed = "wan";
    };
  };

  # Keep only 30 generations in GRUB to prevent /boot overflow
  boot.loader.grub.configurationLimit = 30;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11";
}
