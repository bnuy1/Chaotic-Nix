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
  _module.args.host = host;
  imports = [
    ./modules/core
    ./hosts/${host}
    #./modules/development/minecraft-server
    inputs.silentSDDM.nixosModules.default
  ];
  networking.hostName = networkingHostname;
}
