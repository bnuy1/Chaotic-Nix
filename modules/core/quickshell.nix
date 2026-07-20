{ config, pkgs, lib, ... }:
let
  dm = config.custom.displayManagerParsed;
in lib.mkIf dm.graphical {
  environment.systemPackages = with pkgs; [
    quickshell
    qt6.qt5compat
    qt6.qtbase
    qt6.qtquick3d
    qt6.qtwayland
    qt6.qtdeclarative
    qt6.qtsvg
    qt5.qtgraphicaleffects
  ];

  environment.variables = {
    QML_IMPORT_PATH = "${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtbase}/lib/qt-6/qml";
    QML2_IMPORT_PATH = "${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtbase}/lib/qt-6/qml";
  };

  environment.sessionVariables = {
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
}
