{ config, ... }:
# Disko schema for Raspberry Pi 4 cluster nodes
# Layout:
#   /boot/firmware  — SD card vfat (mmcblk0p1); declared in modules/hardware/rpi4.nix
#   /               — mdadm RAID1 across two USB drives, ext4 (full array, ~28.6 GiB)
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
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
