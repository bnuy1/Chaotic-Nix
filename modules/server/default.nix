# Server module aggregator.
#
# Every server module is ALWAYS imported so that its options
# (services.<name>.*) are declared on every host that defines `serverModules`.
# That way per-host service config (e.g. services.pterodactyl.listenIP) can be
# written in a host's default.nix and survives even while the service is
# disabled, ready to be re-enabled.
#
# vars.serverModules entries:
#   null    = service disabled (default)
#   true    = service enabled with default options
#   attrset = service enabled with those options applied to services.<name>
{ config, lib, vars, inputs, ... }:

let
  serverModuleMap = {
    pterodactyl = ./pterodactyl;
    step-ca = ./step-ca;
    # headscale client (joins the bnuy tailnet as a node): services.vpn
    vpn = ./vpn;
    # headscale server (control plane + exit node + subnet router on
    # singularity): services.vpn-server. Module defined in the vpn flake's
    # nixosModules.headscale; services.vpn-server.enable is set by the
    # aggregator below.
    vpn-server = inputs.vpn.nixosModules.headscale;
    technitium = ./technitium;
    netboot = ./netboot;
    remoteUnlock = ./remote-unlock;
    syncthing = ./syncthing;
    mailcow = ./mailserver;
    # vaultwarden is a self-contained sub-flake (modules/server/vaultwarden),
    # tracked as the `vaultwarden` flake input: services.vaultwarden.
    vaultwarden = inputs.vaultwarden.nixosModules.default;
    # dynamic Cloudflare WAN-DNS reconciler (grey-cloud A records track the
    # rotating home IP): services.cloudflareDns
    cloudflareDns = ./cloudflare-dns;
  };

  # Generate a module per server module that pins services.<name>.enable:
  #   null    -> false (overrides any `default = true` in the module, e.g. pterodactyl)
  #   true    -> true with default options
  #   attrset -> true with those options applied (minus an explicit `enable` key)
  # Uses lib.mkDefault so module-internal enables (e.g. netboot's own services)
  # and explicit host overrides can still win.
  enabledServers = lib.mapAttrsToList (name: value: {
    services.${name} =
      { enable = lib.mkDefault (value != null); }
      // lib.optionalAttrs (builtins.isAttrs value) (removeAttrs value [ "enable" ]);
  }) (vars.serverModules or { });
in
{
  imports = lib.attrValues serverModuleMap ++ enabledServers;
}
