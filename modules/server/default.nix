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
{ config, lib, vars, ... }:

let
  serverModuleMap = {
    pterodactyl = ./pterodactyl;
    vpn = ./vpn;
    technitium = ./technitium;
    netboot = ./netboot;
    remoteUnlock = ./remote-unlock;
  };

  # Generate a module per server module that pins services.<name>.enable:
  #   null    -> false (overrides any `default = true` in the module, e.g. pterodactyl)
  #   true    -> true with default options
  #   attrset -> true with those options applied (minus an explicit `enable` key)
  # Uses lib.mkDefault so module-internal enables (e.g. netboot's own services.vpn)
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
