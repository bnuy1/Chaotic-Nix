{ dm, lib, ... }: {
  imports =
    [
      ./common-user-packages.nix
      ./stylix.nix
    ]
    ++ lib.optionals dm.graphical [
      ./gtk.nix
      ./kitty.nix
      ./fuzzel.nix
      ./foot.nix
      ./wlogout.nix
      ./dunst.nix
      ./spicetify.nix
      ./hyprland
    ];
}
