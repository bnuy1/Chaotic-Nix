{ dm, lib, ... }: {
  imports =
    [
      ./common-user-packages.nix
      ./stylix.nix
    ]
    ++ lib.optionals dm.graphical [
      ./kitty.nix
      ./waybar.nix
      ./dunst.nix
      ./hyprland
    ];
}
