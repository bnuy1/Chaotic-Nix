{
  description = "Self-contained vaultwarden password manager module";

  outputs = { self }: {
    nixosModules.default = import ./default.nix;
    nixosModules.vaultwarden = import ./default.nix;
  };
}
