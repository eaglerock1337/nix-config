{ lib, inputs, ... }: {
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    inputs.nixos-raspberrypi.nixosModules.sd-image
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # Stub root FS so the config evaluates before disko is wired in Phase 5.
  # disko/rpi4.nix will override with the real mdadm RAID layout.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/md0";
    fsType = "ext4";
  };

  # TODO Phase 5: config.txt + EEPROM + thermal
}
