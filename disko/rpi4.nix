{ config, ... }:
# Disko schema for Raspberry Pi 4 cluster nodes (T029)
# Layout:
#   /boot/firmware  — SD card vfat (mmcblk0p1); declared in modules/hardware/rpi4.nix
#   /               — mdadm RAID1 across two USB drives, ext4
#   /srv/usb        — mdadm RAID1 remaining space, ext4 (workload data)
#
# No NVMe on Pi 4 — /srv/ssd mount is absent (FR-010, FR-014).
# Device paths are set per-host in hosts/hlc-4NN/configuration.nix via hlc.disko.*
# options. Fill in real /dev/disk/by-path/ paths before running `make provision`.
# USB: confirm Pi 4 by-path patterns via `ls -la /dev/disk/by-path/ | grep us` on hlc-401.
{
  disko.devices = {
    disk = {
      usb0 = {
        type = "disk";
        device = config.hlc.disko.usbDevice0;
        content = {
          type = "gpt";
          partitions = {
            raid = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "usb-raid";
              };
            };
          };
        };
      };
      usb1 = {
        type = "disk";
        device = config.hlc.disko.usbDevice1;
        content = {
          type = "gpt";
          partitions = {
            raid = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "usb-raid";
              };
            };
          };
        };
      };
    };

    mdadm = {
      usb-raid = {
        type = "mdadm";
        level = 1;
        content = {
          type = "gpt";
          partitions = {
            root = {
              # 50 GiB for root — generous for NixOS store, logs, k3s images;
              # remaining space goes to /srv/usb for workload data
              size = "50G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            usb = {
              size = "100%"; # remaining space
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/srv/usb";
              };
            };
          };
        };
      };
    };
  };
}
