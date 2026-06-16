{ vars, lib, ... }: {
  imports =
    [
      ./common-user-packages.nix
      ./kitty.nix
      ./stylix.nix
    ]
    ++ lib.optionals (vars.displayManager == "sddm") [
      ./hyprland
      ./noctalia.nix
    ];
}
