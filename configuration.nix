{
  pkgs,
  lib,
  host,
  networkingHostname,
  vars,
  inputs,
  ...
}:
{
  imports = [
    ./modules/core
    ./hosts/${host}
    inputs.silentSDDM.nixosModules.default
  ]
  ++ lib.optionals (vars.serverModules or null != null) [
    ./modules/server
  ];

  networking.hostName = networkingHostname;
}
