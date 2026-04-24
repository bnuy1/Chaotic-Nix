{
  pkgs,
  host,
  ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) defaultBackroundImage;
in
{
  # Styling Options
  stylix = {
    enable = true;
    image = defaultBackroundImage;

    polarity = "dark";
    opacity.terminal = 1.0;
    targets = {
      grub.enable = false;
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      sizes = {
        applications = 12;
        terminal = 15;
        desktop = 11;
        popups = 12;
      };
    };
  };
}
