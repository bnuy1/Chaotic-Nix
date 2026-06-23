{ config, lib, pkgs, vars, ... }:
let
  swp = vars.swap or {};
  hibernation = swp.hibernateEnable or vars.hibernateEnable or false;

  # All swap devices declared across all modules (hardware + our swapfile)
  allSwaps = config.swapDevices or [];

  # Swap devices on LUKS: mapper path starts with /dev/mapper/luks-
  luksSwaps = builtins.filter (sd:
    lib.hasPrefix "/dev/mapper/luks-" sd.device
  ) allSwaps;

  # LUKS device name from mapper path: /dev/mapper/luks-xxx -> luks-xxx
  luksNames = map (sd: lib.removePrefix "/dev/mapper/" sd.device) luksSwaps;

  # Keyfile source: prefer persisted /etc/secrets/<name>-keyfile,
  # fall back to generating a random one on first build
  keyfileFor = name:
    let persisted = "/etc/secrets/${name}-keyfile";
    in if builtins.pathExists persisted
       then builtins.path { path = persisted; name = "swap-keyfile-${name}"; }
       else pkgs.runCommand "swap-keyfile-${name}" { } ''
         dd if=/dev/random of=$out bs=32 count=1 status=none
         chmod 0400 $out
       '';

  keyfiles = builtins.listToAttrs (map (name: {
    inherit name;
    value = keyfileFor name;
  }) luksNames);

in {
  config = lib.mkIf (swp.enable or true) {
    zramSwap = {
      enable = true;
      memoryPercent = swp.zramPercent or 100;
      algorithm = swp.algorithm or "zstd";
      priority = 100;
    };

    swapDevices = lib.mkIf hibernation [
      { device = "/swapfile"; size = swp.swapFileSize or 8192; }
    ];

    # Augment LUKS swap initrd devices with keyfile + safe defaults
    boot.initrd.luks.devices = builtins.listToAttrs (map (name: {
      name = name;
      value = {
        keyFile = "/etc/secrets/${name}-keyfile";
        allowDiscards = lib.mkDefault true;
      };
    }) luksNames);

    # Embed keyfile in initrd (stable after first build via builtins.path)
    boot.initrd.secrets = builtins.listToAttrs (map (name: {
      name = "/etc/secrets/${name}-keyfile";
      value = keyfiles.${name};
    }) luksNames);

    boot.resumeDevice = lib.mkIf hibernation (
      if luksSwaps != []
      then (builtins.head luksSwaps).device
      else "/swapfile"
    );

    # Persist keyfile on first boot so future builds produce the same initrd
    system.activationScripts.swap-keyfiles = lib.mkIf (luksNames != []) {
      deps = [ ];
      text = ''
        ${lib.concatStringsSep "\n" (map (name: ''
          if [ ! -f /etc/secrets/${name}-keyfile ]; then
            mkdir -p /etc/secrets
            cp ${keyfiles.${name}} /etc/secrets/${name}-keyfile
            chmod 0400 /etc/secrets/${name}-keyfile
          fi
        '') luksNames)}
      '';
    };

    # One-time enrollment helper per LUKS swap device
    environment.systemPackages = map (sd:
      let
        name = lib.removePrefix "/dev/mapper/" sd.device;
        luksDevPath = lib.attrByPath
          [ "boot" "initrd" "luks" "devices" name "device" ] "" config;
      in pkgs.writeShellScriptBin "enroll-${name}" ''
        set -e
        if [ ! -f /etc/secrets/${name}-keyfile ]; then
          echo "Keyfile not found at /etc/secrets/${name}-keyfile"
          echo "Run 'nixos-rebuild switch' first to generate it."
          exit 1
        fi
        exec cryptsetup luksAddKey ${luksDevPath} /etc/secrets/${name}-keyfile
      ''
    ) luksSwaps;
  };
}
