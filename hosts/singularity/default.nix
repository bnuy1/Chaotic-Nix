{
  config,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
  ];

  services.pterodactyl.listenIP = "192.168.1.166";

  networking.hostId = "deadbeef";
}
