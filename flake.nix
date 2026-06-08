{
  description = "Agnostic Multi-Host NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";

    # SOPS secrets manager (for development) so.. its not required if you recieved this file from a friend.
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      hostDir = ./hosts;
      allHostFolders = builtins.readDir hostDir;

      # Builds a list of every folder name inside /etc/nixos/hosts/
      myHosts = builtins.attrNames (
        nixpkgs.lib.filterAttrs (name: type: type == "directory") allHostFolders
      );

      # The HOST generator/ logic for finding which machine to build
      mkHost =
        networkingHostname:
        let
          # Check if a folder name matches the "PrimaryHost" arbitrary name
          specificPath = hostDir + "/${networkingHostname}";
          hasSpecificConfig = builtins.pathExists specificPath;

          # The Logic to determine weather or not the hostname matches a known host in hostdir otherwise falls back on the Default host
          matchedHost = if hasSpecificConfig then networkingHostname else "default";
          matchedPath = hostDir + "/${matchedHost}";
        in
        nixpkgs.lib.nixosSystem {
          # This sends 'inputs', 'networkingHostname', 'host', and 'vars' to EVERY file
          specialArgs = {
            inherit inputs;
            inherit networkingHostname; # The actual target hostname (e.g., "arbitrary-name")
            host = matchedHost; # The folder matched (e.g., "default" or "antimatter")

            # Safely loads variables from the matched folder, preventing missing file crashes
            vars = import (matchedPath + "/variables.nix");
          };

          modules = [
            ./configuration.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.stylix.nixosModules.stylix
            inputs.noctalia.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            # THE ROUTER:
            # We already proved the path exists above, so we can just pass the matched path.
            matchedPath

            # Inject the arbitrary networking hostname
            { networking.hostName = networkingHostname; }
          ];
        };

    in
    {
      # OUTPUTS
      # Generates nixosConfigurations for all known host folders.
      # Build a specific host with: sudo nixos-rebuild switch --flake .#hostname
      # Falls back to 'hosts/default/' if the hostname doesn't match a folder.
      nixosConfigurations = builtins.listToAttrs (map (name: {
        inherit name;
        value = mkHost name;
      }) myHosts);
    };
}
