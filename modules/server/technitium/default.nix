{ config, lib, pkgs, networkingHostname, ... }:

let
  cfg = config.services.technitium;
in
{
  options.services.technitium = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Technitium DNS Server for local DNS and ad-blocking";
    };

    localDomain = lib.mkOption {
      type = lib.types.str;
      default = "${networkingHostname}.local";
      description = "Local domain to resolve. Create a primary zone for this in the Technitium web UI";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address for Technitium to listen on. Set to LAN IP to serve other machines";
    };

    useLocally = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Configure this host to use Technitium as its DNS resolver";
    };
  };

  config = lib.mkIf cfg.enable {
    services.technitium-dns-server = {
      enable = true;
      openFirewall = true;
    };

    users.users.technitium = {
      isSystemUser = true;
      group = "technitium";
    };
    users.groups.technitium = { };

    systemd.services.technitium-dns-server.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "technitium";
      Group = lib.mkForce "technitium";
      StateDirectory = lib.mkForce "technitium-dns-server";
      ProtectSystem = lib.mkForce "strict";
      LogsDirectory = "technitium";
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 5380 ];
      allowedUDPPorts = [ 53 ];
    };

    networking.nameservers = lib.mkIf cfg.useLocally [ cfg.listenAddress ];

    services.resolved.dnssec = lib.mkIf cfg.useLocally false;

    systemd.tmpfiles.rules = [
      "d /var/lib/technitium-dns-server 0755 technitium technitium -"
      "d /var/log/technitium 0755 technitium technitium -"
    ];
  };
}
