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
    socat
    strace
    tcpdump
    tmux
    traceroute
    tree
    vim
  ];
}
