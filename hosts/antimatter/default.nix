{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
    ../common-host-packages.nix
    ../../modules/hardware/antimatter.nix
  ];

  hardware.antimatter.enable = true;

  # headscale client (serverModules.vpn = true). Before first boot, drop a
  # one-shot pre-auth key at /var/lib/tailscale/preauthkey (see the client
  # module header) — not a SOPS secret, the box is the only host with an age key.
  services.vpn.authKeyFile = "/var/lib/tailscale/preauthkey";

  # Declared while disabled (serverModules.netboot = null) so it survives a
  # future re-enable without re-typing the per-host values.
  services.netboot = {
    listenIp = "192.168.2.182";
    interface = "enp7s0";
  };

  # Documents sync (phone <-> antimatter), plaintext + bidirectional.
  # Declared while disabled (serverModules.syncthing = null) so it survives;
  # add the phone device (with its full device ID) to settings.devices and this
  # folder's `devices` list once known.
  # NOTE: syncthing-init re-pushes this folder on every boot, so until the
  # phone device is declared, GUI-added folder shares get reset on reboot.
  services.syncthing.settings.folders.documents = {
    id = "documents";
    path = "/home/bnuy/Documents";
    devices = [ ];
  };
}
