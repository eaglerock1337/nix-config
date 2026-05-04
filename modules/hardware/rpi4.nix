{ lib, inputs, ... }:
# Raspberry Pi 4 (bcm2711) hardware module (T031, R-011, R-012, R-015)
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    inputs.disko.nixosModules.disko
    ../../disko/rpi4.nix
    ./rpi-eeprom.nix
    # sd-image lives in flake.nix mkHlcBootstrap — not here; provisioned configs
    # never include the SD image module (fileSystems from disko/rpi4.nix in Phase 5)
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.buildPlatform = "x86_64-linux";

  # SD card vfat partition used as firmware/boot partition.
  # disko handles the USB RAID root; this mount is declared here so nixos-install
  # knows to mount mmcblk0p1 at /boot/firmware during provisioning.
  # The SD bootstrap root (mmcblk0p2) is intentionally left untouched by disko —
  # it remains as an operator-accessible recovery environment.
  fileSystems."/boot/firmware" = lib.mkDefault {
    device = "/dev/mmcblk0p1";
    fsType = "vfat";
    options = [ "nofail" "umask=0077" ];
  };

  # Use the generational bootloader (replaces deprecated kernelboot; nvmd PR#61)
  boot.loader.raspberry-pi.bootloader = "kernel";
  # Keep 5 generations on the firmware partition (~53 MiB each); provides rollback
  boot.loader.raspberry-pi.configurationLimit = 5;

  # Pi family for rpi-eeprom.nix — rpi4 uses universal EEPROM settings only
  hlc.piFamily = "rpi4";

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
      # Modest overclock for passive-heatsink Pi 4 (R-012): validated safe under sustained load
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

  # Pi 4 thermal: passive heatsink; 1750 MHz overclock validated (R-012)
  # No nvme dtparam on Pi 4 — no M.2 HAT / PCIe lane on this variant.
}
