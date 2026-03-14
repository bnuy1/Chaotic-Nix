{
  inputs = {
    stylix.url = "github:danth/stylix";
  };
  outputs =
    { nixpkgs, ... }@inputs:
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          inputs.stylix.nixosModules.stylix
        ];
      };
    };

}
