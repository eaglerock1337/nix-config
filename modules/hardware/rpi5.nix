{ lib, inputs, ... }:
# Raspberry Pi 5 (bcm2712) hardware module (T030, R-011, R-012, R-015)
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.disko.nixosModules.disko
    ../../disko/rpi5.nix
    ./rpi-eeprom.nix
    # sd-image lives in flake.nix mkHlcBootstrap — not here; provisioned configs
    # never include the SD image module (fileSystems from disko/rpi5.nix in Phase 5)
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # SD card vfat partition used as firmware/boot partition.
  # disko handles the USB RAID root; this mount is declared here so nixos-install
  # creates /boot/firmware and mounts mmcblk0p1 there before running the bootloader.
  # nofail intentionally omitted: without it nixos-install silently skips creating
  # the mountpoint, causing the Pi firmware cp to fail (confirmed 2026-05-05).
  # The SD card is always present on Pi hardware so mandatory mount is safe.
  # The SD bootstrap root (mmcblk0p2) is intentionally left untouched by disko —
  # it remains as an operator-accessible recovery environment.
  fileSystems."/boot/firmware" = lib.mkDefault {
    device = "/dev/mmcblk0p1";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # Use the generational bootloader (replaces deprecated kernelboot; nvmd PR#61)
  boot.loader.raspberry-pi.bootloader = "kernel";
  # Keep 5 generations on the firmware partition (~53 MiB each); provides rollback
  boot.loader.raspberry-pi.configurationLimit = 5;

  # Pi family for rpi-eeprom.nix — gates Pi 5-specific EEPROM settings
  hlc.piFamily = "rpi5";

  # Headless server config.txt profile (R-011, FR-025)
  # Confirmed option path: hardware.raspberry-pi.config.<section>.{options,base-dt-params,dt-overlays}
  hardware.raspberry-pi.config.all = {
    options = {
      # Minimum GPU memory split; no display use in cluster
      gpu_mem = { enable = true; value = 16; };
      # Suppress firmware boot splash (meaningless on headless)
      disable_splash = { enable = true; value = 1; };
      # Zero firmware boot delay
      boot_delay = { enable = true; value = 0; };
    };
    base-dt-params = {
      # Disable on-board audio (no use case; saves a small driver surface)
      # mkForce required: nvmd configtxt.nix sets audio="on" at normal priority
      audio = { enable = lib.mkForce true; value = lib.mkForce "off"; };
      # Enable M.2 HAT PCIe lane for NVMe — must be set at firmware time, not kernel
      nvme = { enable = true; };
    };
    dt-overlays = {
      # Disable Bluetooth; frees UART for serial console debug if needed
      disable-bt = { enable = true; };
    };
  };

  # Pi 5 class-level disko device defaults (same SoC addresses across all Pi 5 units)
  hlc.disko.usbDevice0 = lib.mkDefault "/dev/disk/by-path/platform-xhci-hcd.0-usb-0:1:1.0-scsi-0:0:0:0";
  hlc.disko.usbDevice1 = lib.mkDefault "/dev/disk/by-path/platform-xhci-hcd.1-usb-0:1:1.0-scsi-0:0:0:0";
  hlc.disko.nvmeDevice = lib.mkDefault "/dev/nvme0n1";
}
