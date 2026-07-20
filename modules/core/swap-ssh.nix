{ config, lib, pkgs, vars, ... }:

let
  cfg = vars.swap or {};

  # LUKS swap UUID from host variables
  luksSwapUuid = cfg.luksSwapUuid or null;
  hasLuksSwap = luksSwapUuid != null && luksSwapUuid != "";
  hibernateEnabled = vars.hibernateEnable or false;
in
{
  config = {
    assertions = [
      {
        assertion = !(hasLuksSwap && hibernateEnabled);
        message = ''
          swap.luksSwapUuid and hibernateEnable cannot both be set.
          LUKS swap with a random key loses the key on reboot, making hibernation impossible.
        '';
      }
    ];

    # LUKS initrd device for swap (UUID from host variables)
    boot.initrd.luks.devices = lib.mkIf hasLuksSwap {
      swap = {
        device = "/dev/disk/by-uuid/${luksSwapUuid}";
        allowDiscards = true;
      };
    };
  };
}
