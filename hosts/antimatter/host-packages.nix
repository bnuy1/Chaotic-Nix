{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    tor
    tor-browser
    # Media and file sharing
    qbittorrent
    yt-dlp
    # Machine Specific Development
    drogon
    hugo
    jdk21_headless
    vscode-langservers-extracted
  ];
}
