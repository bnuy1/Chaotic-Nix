{ config, ... }:

{
  programs.foot = {
    enable = true;
  };

  xdg.configFile."foot/foot.ini".text = ''
    include=${config.home.homeDirectory}/.config/foot/colors.ini
    shell=fish
    term=xterm-256color

    title=foot
    font=Iosevka:size=11
    letter-spacing=0
    dpi-aware=no

    pad=25x25

    bold-text-in-bright=no

    [scrollback]
    lines=10000

    [cursor]
    style=beam
    blink=no
    beam-thickness=1.5

    [key-bindings]
    scrollback-up-page=Page_Up
    scrollback-down-page=Page_Down
    clipboard-copy=Control+c
    clipboard-paste=Control+v
    search-start=Control+f
    font-increase=Control+plus Control+equal Control+KP_Add
    font-decrease=Control+minus Control+KP_Subtract
  '';
}
