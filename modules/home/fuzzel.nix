{ config, ... }:

{
  programs.fuzzel = {
    enable = true;
  };

  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    include=${config.home.homeDirectory}/.config/fuzzel/fuzzel_theme.ini
    font=Iosevka:size=11
    terminal=kitty -1
    prompt=">>  "
    layer=overlay

    [border]
    radius=17
    width=1

    [dmenu]
    exit-immediately-if-empty=yes
  '';
}
