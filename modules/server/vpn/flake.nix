{
  description = "Self-contained headscale VPN module";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";

  outputs = { self, nixpkgs }: {
    nixosModules.headscale = import ./headscale.nix;
    nixosModules.default = import ./headscale.nix;
  };
}
