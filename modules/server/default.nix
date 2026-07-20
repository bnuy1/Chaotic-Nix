{ lib, vars, ... }:
let
  serverModuleMap = {
    pterodactyl = ./pterodactyl;
    vpn = ./vpn;
    technitium = ./technitium;
    netboot = ./netboot;
    remoteUnlock = ./remote-unlock;
  };

  # Filter to enabled modules (true or attrset, not null)
  enabledServers = lib.filterAttrs (_: v: v != null) (vars.serverModules or { });
  serverImports = map (name: serverModuleMap.${name}) (builtins.attrNames enabledServers);

  # Merge netboot config if provided as attrset
  netbootConfig =
    let netbootVal = vars.serverModules.netboot or null;
    in if netbootVal != null && builtins.isAttrs netbootVal then
      [{ services.netboot = netbootVal // { enable = true; }; }]
    else if netbootVal == true then
      [{ services.netboot.enable = true; }]
    else [];
in
{
  imports = serverImports ++ netbootConfig;
}
