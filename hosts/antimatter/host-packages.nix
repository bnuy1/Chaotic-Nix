{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Machine Specific Development
    ollama
    opencode

    tcpdump
    netcat
    ipmitool
    dnsmasq
    arp-scan

    adoptopenjdk-icedtea-web

    tor
    tor-browser
    # Media and file sharing
    qbittorrent
    yt-dlp
    # Machine Specific Development
    cargo
    rustc
    jdk21_headless
    vscode-langservers-extracted
    rpi-imager
    # Hardware Specific
    rocmPackages.rocm-smi
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };

  systemd.services.ollama = {
    serviceConfig = {
      Environment = "OLLAMA_CONTEXT_LENGTH=64000";
      ExecStart = "${pkgs.ollama-rocm}/bin/ollama serve";
      Restart = "on-failure";
    };
  };
  services.flatpak.enable = true;
}
