{ lib, vars, config, ... }:
let
  snap = vars.snapshots or {};
  enabled = snap.enable or false;

  rootFs = config.fileSystems."/" or {};
  fsType = rootFs.fsType or null;
  device = rootFs.device or null;

  subvolFromOpts = opts:
    let
      prefix = "subvol=";
      matches = builtins.filter (o: lib.hasPrefix prefix o) opts;
    in
    if matches != [] then lib.removePrefix prefix (builtins.head matches) else null;

  rootOpts = rootFs.options or [];
  rootSubvol = subvolFromOpts rootOpts;

  btrfsMounts = lib.filterAttrs (name: fs: fs.fsType or "" == "btrfs") config.fileSystems;
  snapExclude = snap.exclude or [ "/nix" ];

  btrbkSubvols = lib.listToAttrs (builtins.concatMap (mountpoint:
    let
      fs = btrfsMounts.${mountpoint};
      subvol = subvolFromOpts (fs.options or []);
    in
    if subvol != null then [{
      name = subvol;
      value = {
        snapshot_create = if builtins.elem mountpoint snapExclude then "no" else "always";
      };
    }] else []
  ) (builtins.attrNames btrfsMounts));

  keep = key: def: let v = (snap.retention or {}).${key}; in if v != null then v else def;

  ret = {
    hourly  = keep "hourly"  24;
    daily   = keep "daily"   7;
    weekly  = keep "weekly"  4;
    monthly = keep "monthly" 6;
    yearly  = keep "yearly"  0;
  };

  schedule = snap.schedule or "hourly";

  autoTool = if fsType == "btrfs" then "btrbk"
    else if fsType == "zfs" then "sanoid"
    else null;

  btrbkEnabled = enabled && autoTool == "btrbk" && device != null;
  sanoidEnabled = enabled && autoTool == "sanoid";
  ext4Warning = enabled && (fsType == "ext4" || fsType == null);
in
{
  config = lib.mkMerge [
    (lib.mkIf btrbkEnabled {
      boot.supportedFilesystems = [ "btrfs" ];
      services.btrfs.autoScrub.enable = true;

      services.btrbk.instances.local = {
        onCalendar = schedule;
        settings = {
          snapshot_preserve = "${toString ret.hourly}h ${toString ret.daily}d ${toString ret.weekly}w ${toString ret.monthly}m";
          snapshot_preserve_min = "${toString ret.daily}d";
          volume.${device}.subvolume = btrbkSubvols;
        };
      };
    })

    (lib.mkIf sanoidEnabled {
      services.sanoid = {
        enable = true;
        interval = schedule;
        templates.default = {
          hourly  = ret.hourly;
          daily   = ret.daily;
          weekly  = ret.weekly;
          monthly = ret.monthly;
          yearly  = ret.yearly;
        };
      };
    })

    (lib.mkIf ext4Warning {
      warnings = [ "ext4 filesystem detected — snapshots disabled (use btrfs or zfs for snapshot support)" ];
    })
  ];
}
