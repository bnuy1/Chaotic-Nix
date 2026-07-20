{ config, lib, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
    ./zfs.nix
  ];

  services.pterodactyl.listenIP = "192.168.1.166";

  networking.hostId = "8425e349";

  # Initrd kernel modules for mounting /boot (FAT32)
  boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" ];

  # Post-boot static IPs via NetworkManager
  networking.networkmanager.ensureProfiles.profiles =
    vars.networking.staticProfiles or {};

  # Remote unlock via initrd SSH
  services.remoteUnlock = {
    enable = true;
    hostKeys = [ /etc/secrets/initrd/ssh_host_ed25519_key ];
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNohenCiYWNpZXB05tskL/aP3aYWYtmO8PTz2INP0Up"
    ];
  };

  # Static IPs for both NICs in initrd
  boot.initrd.systemd.network = {
    enable = vars.initrdUnlock.enable or false;
    networks = vars.initrdUnlock.networks or {};
  };

  users.users.admin.initialPassword = "password";
}
