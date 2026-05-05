{ config, lib, ... }:
# Disko schema for Raspberry Pi 5 cluster nodes (T028)
# Layout:
#   /boot/firmware  — SD card vfat (mmcblk0p1); declared in modules/hardware/rpi5.nix
#   /               — mdadm RAID1 across two USB drives, ext4
#   /srv/usb        — mdadm RAID1 remaining space, ext4 (workload data)
#   /srv/ssd        — NVMe xfs (Pi 5 M.2 HAT); omitted when nvmeDevice is null
#
# Device paths are set per-host in hosts/hlc-5NN/configuration.nix via hlc.disko.*
# options. Fill in real /dev/disk/by-path/ paths before running `make provision`.
# USB (identical across all Pi 5 nodes — fixed SoC addresses, FR-010a):
#   left (a-drive):  platform-xhci-hcd.0-usb-0:1:1.0-scsi-0:0:0:0
#   right (b-drive): platform-xhci-hcd.1-usb-0:1:1.0-scsi-0:0:0:0
# NVMe: /dev/nvme0n1 (only one NVMe slot per Pi 5; no ambiguity)
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
    } // lib.optionalAttrs (config.hlc.disko.nvmeDevice != null) {
      nvme = {
        type = "disk";
        device = config.hlc.disko.nvmeDevice;
        content = {
          type = "gpt";
          partitions = {
            ssd = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/srv/ssd";
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
