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
  hasServerModules = lib.filterAttrs (_: v: v != null) (vars.serverModules or { }) != { };
in
{
  imports = [
    ./modules/core
    ./hosts/${host}
    inputs.silentSDDM.nixosModules.default
  ]
  ++ lib.optionals hasServerModules [
    ./modules/server
  ];

  networking.hostName = networkingHostname;
}
