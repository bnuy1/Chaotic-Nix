{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./host-packages.nix
    ../common-host-packages.nix
    ../../modules/hardware/t440p.nix
  ];

  hardware.thinkpad-t440p.enable = true;
  hardware.thinkpad-t440p.gpu = "nvidia";

  # headscale client (serverModules.vpn = true). Before first boot, drop a
  # one-shot pre-auth key at /var/lib/tailscale/preauthkey (see the client
  # module header) — not a SOPS secret, the box is the only host with an age key.
  services.vpn.authKeyFile = "/var/lib/tailscale/preauthkey";
}
