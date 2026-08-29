{ config, lib, pkgs, ... }:

let
  cfg = config.services.syncthing;
  # Home LANs allowed to reach the GUI/sync ports. Keep in sync with the
  # vpn-server ACL adminSubnets (same trust tier: bnuy/staff machines).
  lanSubnets = [
    "192.168.1.0/24"
    "192.168.2.0/24"
  ];
in
{
  config = lib.mkIf cfg.enable {
    services.syncthing = {
      user = lib.mkDefault "syncthing";
      group = lib.mkDefault "syncthing";

      # Web GUI bound wide so every NIC serves it; the firewall below decides
      # who can reach it: LAN + tailnet only, never WAN (no port forward,
      # by policy). Tailnet guests get none of these ports either.
      # TODO: manage via sops (guiPasswordFile) when wiring up sops.
      guiAddress = lib.mkDefault "0.0.0.0:8384";

      # Ports are opened by hand in extraCommands, restricted by source.
      openDefaultPorts = lib.mkDefault false;

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
      "d /var/backups/syncthing 0755 root root -"
      "d /var/backups/syncthing/repo 0755 root root -"
    ];

    systemd.services.syncthing.serviceConfig.UMask = "0002";

    # GUI (8384/tcp), sync (22000/tcp+udp), LAN discovery (21027/udp).
    networking.firewall.extraCommands =
      let
        subnets = lib.concatStringsSep "," lanSubnets;
      in
      ''
        iptables -A nixos-fw -p tcp -m multiport --dports 8384,22000 -s ${subnets} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -m multiport --dports 21027,22000 -s ${subnets} -j nixos-fw-accept
        iptables -A nixos-fw -i tailscale0 -p tcp -m multiport --dports 8384,22000 -j nixos-fw-accept
        iptables -A nixos-fw -i tailscale0 -p udp --dport 22000 -j nixos-fw-accept
        ip6tables -A nixos-fw -i tailscale0 -p tcp -m multiport --dports 8384,22000 -j nixos-fw-accept
        ip6tables -A nixos-fw -i tailscale0 -p udp --dport 22000 -j nixos-fw-accept
      '';

    sops.secrets."syncthing/backup_password" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };

    systemd.services.syncthing-backup = {
      description = "Syncthing: restic backup (config, certs, device keys)";
      after = [ "syncthing.service" "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      path = [ pkgs.restic pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ReadWritePaths = [ "/var/backups/syncthing" ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        Nice = 10;
        Environment = "RESTIC_CACHE_DIR=/var/cache/restic";
      };
      script = ''
        set -eu
        export RESTIC_PASSWORD=$(cat ${config.sops.secrets."syncthing/backup_password".path})
        export RESTIC_REPOSITORY=/var/backups/syncthing/repo
        mkdir -p /var/backups/syncthing/repo

        if ! restic snapshots >/dev/null 2>&1; then
          restic init
        fi
        restic backup /var/lib/syncthing --tag syncthing
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
      '';
    };

    systemd.timers.syncthing-backup = {
      description = "Syncthing: nightly backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 08:00:00";
        Persistent = true;
      };
    };
  };
}
