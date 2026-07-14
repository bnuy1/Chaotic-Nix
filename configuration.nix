{
  pkgs,
  lib,
  host,
  networkingHostname,
  vars,
  inputs,
  ...
}:
let
  serverModuleMap = {
    pterodactyl = ./modules/server/pterodactyl;
    vpn = ./modules/server/vpn;
    technitium = ./modules/server/technitium;
    netboot = ./modules/server/netboot;
  };

  # Filter to enabled server modules (true or attrset, not null)
  enabledServers = lib.filterAttrs (_: v: v != null) (vars.serverModules or { });

  serverImports = map (name: serverModuleMap.${name}) (builtins.attrNames enabledServers);

  # Merge netboot config: if serverModules.netboot is an attrset, pass it as services.netboot
  netbootConfig =
    let netbootVal = vars.serverModules.netboot or null;
    in if netbootVal != null && builtins.isAttrs netbootVal then
      [{ services.netboot = netbootVal // { enable = true; }; }]
    else if netbootVal == true then
      [{ services.netboot.enable = true; }]
    else [];
in
{
  imports = [
    ./modules/core
    ./hosts/${host}
    #./modules/development/minecraft-server
    inputs.silentSDDM.nixosModules.default
  ]
  ++ serverImports
  ++ netbootConfig;
  networking.hostName = networkingHostname;
}
