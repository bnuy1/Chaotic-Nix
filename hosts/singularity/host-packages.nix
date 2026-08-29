{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Server utilities
    ethtool
    fastfetch
    iotop
    iperf3
    lsof
    mtr
    nftables
    nmap
    sbctl # Secure Boot key management (lanzaboote)
    socat
    strace
    tcpdump
    tmux
    traceroute
    tree
    vim

    # Machine Specific Development
    opencode
  ];
}
