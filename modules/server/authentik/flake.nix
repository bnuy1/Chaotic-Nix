{
  description = "Self-contained authentik single-sign-on (SSO) / IdP module";

  outputs = { self }: {
    nixosModules.default = import ./default.nix;
    nixosModules.authentik = import ./default.nix;
  };
}
