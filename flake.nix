{
  description = "Agnostic Multi-Host NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dots-hyprland = {
      url = "github:end-4/dots-hyprland";
      flake = false;
    };

    # shapes submodule (end4's material shapes library)
    rounded-polygon = {
      url = "github:end-4/rounded-polygon-qmljs";
      flake = false;
    };

    # Spicetify theme manager for Spotify (home-manager module)
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Disk Partitioning
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # Manual override: set to a host folder name (e.g. "singularity") to force
      # ALL nixosConfigurations to use that host's config regardless of the flake
      # attribute name or the machine's hostname. Set to null for normal behavior.
      manualHostname = null;

      hostDir = ./hosts;
      allHostFolders = builtins.readDir hostDir;

      # Builds a list of every folder name inside /etc/nixos/hosts/
      # skip dirs without variables.nix (e.g. build artifacts like result/)
      myHosts = builtins.attrNames (
        nixpkgs.lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (hostDir + "/${name}/variables.nix")
        ) allHostFolders
      );

      # The HOST generator/ logic for finding which machine to build
      mkHost =
        networkingHostname:
        let
          # When manualHostname is set, it overrides the host folder selection
          # for all configurations. This lets you force a specific host setup
          # regardless of what --flake .#name or the machine's hostname says.
          folderBase = if manualHostname != null then manualHostname else networkingHostname;

          # Check if a folder name matches, otherwise falls back on the Default host
          specificPath = hostDir + "/${folderBase}";
          hasSpecificConfig = builtins.pathExists specificPath;

          matchedHost = if hasSpecificConfig then folderBase else "default";
          matchedPath = hostDir + "/${matchedHost}";
        in
        nixpkgs.lib.nixosSystem {
          # This sends 'inputs', 'networkingHostname', 'host', and 'vars' to EVERY file
          specialArgs =
            let
              # Load default vars first, then merge host vars on top
              # Hosts only need to override what differs from default
              defaultVars = import (hostDir + "/default/variables.nix");
              hostVars = import (matchedPath + "/variables.nix");
            in
            {
              inherit inputs;
              inherit networkingHostname; # The actual target hostname (e.g., "arbitrary-name")
              host = matchedHost; # The folder matched (e.g., "default" or "antimatter")

              # Safely loads variables from the matched folder, preventing missing file crashes
              vars = nixpkgs.lib.recursiveUpdate defaultVars hostVars;
            };

          modules = [
            ./configuration.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            # THE ROUTER:
            # We already proved the path exists above, so we can just pass the matched path.
            matchedPath

            # Inject the arbitrary networking hostname
            { networking.hostName = networkingHostname; }
          ];
        };

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # Locked disko CLI (used via `nix run /etc/nixos#disko -- --flake ...`)
      packages = forAllSystems (system: {
        disko = inputs.disko.packages.${system}.disko;
      });

      nixosConfigurations = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = mkHost name;
        }) myHosts
      );
    };
}
