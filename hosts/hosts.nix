{ config, pkgs, lib, ... }:

let
  # Available Options: 
  # default, 
  # Note: If this is set, it overrides the env checking 
  override_Host = "";

  # Read the system hostname and fucking explode the inane amount of newlines and spaces
  envHostname = builtins.elemAt (builtins.split "\n" (builtins.readFile /etc/hostname)) 0;

  # check if overides or if the env hostname is not valid
  hostname =
    if override_Host != "" then override_Host
    else if envHostname != "" then envHostname
    else "default";

  # Relative location of any given host
  hostFile = ./${hostname}/default.nix;

  # Check if everything is valid and have a go to default host if not because lol
  selectedHost =
    if builtins.pathExists hostFile
    then hostFile
    else ./default/default.nix;

in
{
  imports = [
    selectedHost
  ];
}
