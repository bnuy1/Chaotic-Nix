# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./system
      ./hosts/hosts.nix 
      ./modules
      ./raina/raina.nix
    ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable redistributable firmware (needed for Qualcomm Wi-Fi)
  hardware.enableRedistributableFirmware = true;

  # Ensure firmware package is present
  hardware.firmware = with pkgs; [
    linux-firmware
  ];

  networking.hostName = "antimatter"; # Define your hostname.

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  
    # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

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

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true

    #media-session.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.fur3 = {
    isNormalUser = true;
    description = "M";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    
    openssh.authorizedKeys.keys = [
    # Public Key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDpAOcERg7AdXnDJrEjars/3dUPzVpIhYCYufTExq+m enigma558@proton.me"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVesdo9hHwSnHBT/QGDegemV63jrvuCcBL8nv/oX3Jc T44P ARCH"
    ];
  };

  # Firefox.
  programs.firefox.enable = true;
  # Fish
  programs.fish.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = false;

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
     kitty
     nano
     git
     bc
     brightnessctl
     plymouth
     hyprsunset
     qbittorrent
     wireguard-tools
     yt-dlp
     dunst
     mullvad-vpn
     jellyfin
     jellyfin-desktop
     blueman
     zip
     unzip
     hugo
     vscode-langservers-extracted
     kdePackages.dolphin
     moonlight-qt
     element-desktop
     ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wlp6s0" ]; # Qualcomm Wi-Fi interface
  };

  services.openssh = {
    enable = true;
    ports = [ 5432 ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "raina" "fur3" ];
    };
  };
  # Open ports in the firewall.           ssh  
  networking.firewall.allowedTCPPorts = [ 5432 ];
  networking.firewall.allowedUDPPorts = [ 5432 47998 47999 48000 48002 ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
