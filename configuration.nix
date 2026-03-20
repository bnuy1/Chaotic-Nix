{
  pkgs,
  host,
  networkingHostname,
  ...
}:
{
  _module.args.host = host;
  imports = [
    ./modules/core
    ./hosts/${host}
    ./modules/development/minecraft-server
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

  networking.hostName = networkingHostname; # Define your hostname.

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  #services.desktopManager.plasma6.enable = true;

  #XDG_CURRENT_DESKTOP=GNOME element-desktop
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  programs.fish.enable = true;

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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
  ];

  environment.systemPackages = with pkgs; [
    nano
    git
    bc
    brightnessctl
    plymouth
    hyprsunset
    wireguard-tools
    dunst
    mullvad-vpn
    jellyfin
    jellyfin-desktop
    blueman
    zip
    unzip
    kdePackages.dolphin
    moonlight-qt
    element-desktop
    kitty
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11";
}
