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
  ];

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

  networking.hostName = networkingHostname;

  # Enable the X11 windowing system and related services only for graphical hosts.
  services.xserver.enable = vars.displayManager == "sddm";
  services.displayManager.sddm.enable = vars.displayManager == "sddm";

  #XDG_CURRENT_DESKTOP=GNOME element-desktop
  services.gnome.gnome-keyring.enable = vars.displayManager == "sddm";
  security.pam.services.hyprland.enableGnomeKeyring = vars.displayManager == "sddm";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = vars.keyboardLayout;
    variant = vars.keyboardVariant;
  };

  # Gaming optimizations
  programs.gamemode.enable = vars.displayManager == "sddm";
  hardware.graphics = lib.mkIf (vars.displayManager == "sddm") {
    extraPackages = with pkgs; [ mangohud ];
    extraPackages32 = with pkgs; [ mangohud ];
  };
  # SSD trimming (safe: only issues TRIM to devices that support it)
  services.fstrim.enable = true;

  programs.fish.enable = true;

  programs.nix-ld.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkIf (vars.displayManager == "sddm") "1";

  services.sunshine = {
    enable = vars.sunshineEnable or false;
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
  # File manager: Dolphin (default) or Thunar
  programs.thunar.enable = vars.thunarEnable or false;

  system.stateVersion = "25.11";
}
