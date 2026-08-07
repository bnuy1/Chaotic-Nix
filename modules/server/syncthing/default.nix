{ config, lib, ... }:

let
  cfg = config.services.syncthing;
in
{
  config = lib.mkIf cfg.enable {
    services.syncthing = {
      user = lib.mkDefault "syncthing";
      group = lib.mkDefault "syncthing";

      # Web GUI on the LAN for phone pairing.
      # TODO: manage via sops (guiPasswordFile) when wiring up sops.
      guiAddress = lib.mkDefault "0.0.0.0:8384";

      # Transfer and discovery ports (TCP 22000, UDP 21027/22000).
      # LAN now and over the WireGuard mesh later.
      openDefaultPorts = lib.mkDefault true;

      # Phase 1: pair the phone via the GUI; don't purge GUI-made devices/folders.
      # Flip to true once the phone device is declared in Nix.
      overrideDevices = lib.mkDefault false;
      overrideFolders = lib.mkDefault false;

      settings.options = {
        # Minimal trust: decline usage reporting, no public relay servers.
        urAccepted = lib.mkDefault (-1);
        relaysEnabled = lib.mkDefault false;
        # LAN discovery so the phone finds antimatter automatically.
        localAnnounceEnabled = lib.mkDefault true;
      };
    };

    # Extra hardening for the service account the nixpkgs module creates.
    users.users.syncthing = {
      isSystemUser = true;
      shell = "/run/current-system/sw/bin/nologin";
    };

    # Grant the syncthing user access to the synced folder only, via ACLs
    # scoped to bnuy + syncthing. UMask makes files Syncthing creates
    # ACL-writable so both users can edit them both ways.
    systemd.tmpfiles.rules = [
      "d /home/bnuy/Documents 0755 bnuy users -"
      "a+ /home/bnuy - - - u:syncthing:x"
      "a+ /home/bnuy/Documents - - - u:syncthing:rwx,d:u:bnuy:rwx,d:u:syncthing:rwx"
    ];

    systemd.services.syncthing.serviceConfig.UMask = "0002";

    # Web GUI reachable from the LAN.
    networking.firewall.allowedTCPPorts = [ 8384 ];
  };
}
