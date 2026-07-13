{ config, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
  ];

  services.pterodactyl.listenIP = "192.168.1.166";

  networking.hostId = "8425e349";

  boot.zfs.requestEncryptionCredentials = true;

  boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" ];

  boot.initrd.luks.devices."swap" = {
    device = "/dev/disk/by-uuid/714230b7-3382-4de4-aa51-c8d66f660995";
    allowDiscards = true;
    keyFile = "/dev/urandom";
    keyFileSize = 64;
    fallbackToPassword = false;
    crypttabExtraOpts = [ "plain" ];
  };

  users.users.admin.initialPassword = "password";

  services.vpn = {
    enable = true;
    interface = "wg0";
    listenPort = 51820;
    host = {
      address = "10.0.0.2/24";
      privateKeyFile = "/etc/secrets/wireguard-key";
    };
    peers = [
      {
        name = "antimatter";
        publicKey = "kKvl0rIkq2bMU1+Y6nsSQgPR7HMOsH9pJjRAJw7N6CI=";
        allowedIPs = [ "10.0.0.1/32" ];
        endpoint = "192.168.1.166:51820";
        persistentKeepalive = 25;
      }
    ];
  };
}
