# Singularity disk layout, managed by disko.
#
# disko takes the running system's fileSystems/swapDevices from disko.devices.
#
# Layout:
#   - Intel SSD 240G: 5G /boot (vfat) + 128G swap (random-encrypted) + rest -> "fast" pool
#   - 4x 2TB HDDs (raidz1, survives 1 disk failure) -> "bulk" pool
#   - Both pools: ZFS native encryption (aes-256-gcm, passphrase, keylocation=prompt)
#
# future plan: after a 2nd SSD is installed, mirror the "fast" pool with:
#   zpool attach fast <existing-ssd> <new-ssd>
{ config, lib, ... }:

{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-INTEL_SSDSC2CT240A3_CVMP228407PU240DGN";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "5G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0022"
                  "dmask=0022"
                ];
              };
            };
            swap = {
              size = "128G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            fast = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "fast";
              };
            };
          };
        };
      };
      hdd1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EARX-00PASB0_WD-WMAZA7327080";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "bulk";
              };
            };
          };
        };
      };
      hdd2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EARX-00PASB0_WD-WMAZA7366358";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "bulk";
              };
            };
          };
        };
      };
      hdd3 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EARX-00PASB0_WD-WMAZA7822812";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "bulk";
              };
            };
          };
        };
      };
      hdd4 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000DM001-1ER164_Z4Z5P508";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "bulk";
              };
            };
          };
        };
      };
    };

    zpool = {
      fast = {
        type = "zpool";
        # single vdev (no redundancy) until a 2nd SSD is attached via
        # `zpool attach fast <old> <new>` to turn it into a mirror
        mode = "";
        options = {
          cachefile = "none";
          ashift = "12";
        };
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          atime = "off";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
        };
      };
      bulk = {
        type = "zpool";
        mode = "raidz1"; # 4x 2TB, survives one disk failure
        options = {
          cachefile = "none";
          ashift = "12";
        };
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          atime = "off";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
        };
        datasets = {
          games = {
            type = "zfs_fs";
            mountpoint = "/games";
          };
          documents = {
            type = "zfs_fs";
            mountpoint = "/documents";
          };
        };
      };
    };
  };

  # keep /documents mounted early
  fileSystems."/documents".neededForBoot = true;
}
