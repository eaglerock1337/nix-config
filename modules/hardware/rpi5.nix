{ lib, inputs, ... }: {
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    # sd-image lives in flake.nix mkHlcBootstrap — not here; provisioned configs
    # never include the SD image module (fileSystems from disko/rpi5.nix in Phase 5)
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.buildPlatform = "x86_64-linux";

  # Placeholder root; disko/rpi5.nix (T028) overrides with real mdadm RAID layout.
  # Safe here because sd-image is no longer in this module — no initramfs conflict.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/md0";
    fsType = "ext4";
  };

  # Use the new generational bootloader (replaces deprecated kernelboot)
  boot.loader.raspberry-pi.bootloader = "kernel";

  # TODO Phase 5: config.txt + EEPROM + NVMe + thermal
}
