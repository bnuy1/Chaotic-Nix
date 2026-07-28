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
  hasServerModules = builtins.length (
    builtins.attrNames (
      lib.filterAttrs (_: v: v != null) (vars.serverModules or { })
    )
  ) > 0;
in
{
  imports = [
    ./modules/core
    ./hosts/${host}
    inputs.silentSDDM.nixosModules.default
  ] ++ lib.optionals hasServerModules [
    ./modules/server
  ];

  networking.hostName = networkingHostname;

  # Silence boot.zfs.forceImportRoot warning (safe default for all hosts)
  boot.zfs.forceImportRoot = false;
}
