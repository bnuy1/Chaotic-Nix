{
  pkgs,
  lib,
  host,
  networkingHostname,
  vars,
  ...
}:
{
  _module.args.host = host;
  imports = [
    ./modules/core
    ./hosts/${host}
    ./modules/development/minecraft-server
  ];
  networking.hostName = networkingHostname;
}
