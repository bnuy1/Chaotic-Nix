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
    #./modules/development/minecraft-server
    ./modules/server
    inputs.silentSDDM.nixosModules.default
  ];
  networking.hostName = networkingHostname;
}
