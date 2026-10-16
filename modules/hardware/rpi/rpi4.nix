{ lib, inputs, ... }:
# Raspberry Pi 4 (bcm2711) hardware module
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    inputs.disko.nixosModules.disko
    ../../../disko/rpi4.nix
    ./rpi-eeprom.nix
    # sd-image module lives in flake.nix mkHlcBootstrap — do not include here
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

  # Pi family for rpi-eeprom.nix — rpi4 uses universal EEPROM settings only
  hlc.piFamily = "rpi4";

  # Headless server config.txt profile
  # Confirmed option path: hardware.raspberry-pi.config.<section>.{options,base-dt-params,dt-overlays}
  hardware.raspberry-pi.config.all = {
    options = {
      # Minimum GPU memory split; no display use in cluster
      gpu_mem = { enable = true; value = 16; };
      # Suppress firmware boot splash (meaningless on headless)
      disable_splash = { enable = true; value = 1; };
      # Zero firmware boot delay
      boot_delay = { enable = true; value = 0; };
      # Modest overclock for passive-heatsink Pi 4: validated safe under sustained load
      # 1750 MHz with over_voltage=2 stays well within passive cooling margin
      over_voltage = { enable = true; value = 2; };
      arm_freq = { enable = true; value = 1750; };
    };
    base-dt-params = {
      # Disable on-board audio (no use case; saves a small driver surface)
      # mkForce required: nvmd configtxt.nix sets audio="on" at normal priority
      audio = { enable = lib.mkForce true; value = lib.mkForce "off"; };
    };
    dt-overlays = {
      # Disable Bluetooth; frees UART for serial console debug if needed
      disable-bt = { enable = true; };
    };
  };

  # Pi 4 class-level disko device defaults (same SoC addresses across all Pi 4 units)
  hlc.disko.usbDevice0 = lib.mkDefault "/dev/disk/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usbv3-0:2:1.0-scsi-0:0:0:0";
  hlc.disko.usbDevice1 = lib.mkDefault "/dev/disk/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usbv3-0:1:1.0-scsi-0:0:0:0";
  hlc.disko.nvmeDevice = lib.mkDefault null;
}
