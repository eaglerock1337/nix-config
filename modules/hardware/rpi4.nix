# Raspberry Pi 4 (bcm2711) hardware configuration.
# Provides board selection, cgroup kernel parameters, and hardware quirks.
# Import this module in any Pi4 host configuration.
{ lib, inputs, ... }:

{
  raspberry-pi-nix.board = "bcm2711";

  # cgroup v1 memory subsystem required by k3s (and container runtimes generally)
  boot.kernelParams = [
    "cgroup_memory=1"
    "cgroup_enable=memory"
    "cgroup_enable=cpuset"
  ];

  # nixos-hardware Pi4 module sets reasonable defaults for USB, ethernet, and HDMI,
  # but it also enables generic-extlinux-compatible which conflicts with raspberry-pi-nix's
  # u-boot based bootloader. Force extlinux off so raspberry-pi-nix wins.
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;

  imports = [ inputs.nixos-hardware.nixosModules.raspberry-pi-4 ];
}
