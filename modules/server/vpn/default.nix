{ ... }: {
  imports = [
    # headscale client (services.vpn) — join the bnuy tailnet as a node.
    ./client.nix
  ];
}
