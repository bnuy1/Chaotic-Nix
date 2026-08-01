{ ... }:

{
  # GTK theming applied at runtime by apply-app-themes.sh from the quickshell palette
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = null;
    };
    font = {
      name = "Montserrat";
      package = null;
      size = 12;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = null;
      size = 24;
    };
    # gtk4 apps are themed by the runtime gtk.css; don't inherit the gtk3 theme
    gtk4.theme = null;
  };

  qt = {
    enable = true;
    platformTheme = {
      name = "gtk";
    };
  };

  dconf = {
    enable = true;
    settings."org.gnome.desktop.interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      cursor-theme = "Bibata-Modern-Ice";
      cursor-size = 24;
    };
  };
}
