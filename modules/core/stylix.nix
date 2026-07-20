{
  pkgs,
  vars,
  ...
}:
{
  # Styling Options
  stylix = {
    enable = true;
    image = vars.defaultBackgroundImage;

    polarity = vars.stylixPolarity or "dark";
    opacity.terminal = 1.0;
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
        package = pkgs.noto-fonts;
        name = "Noto Serif";
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
