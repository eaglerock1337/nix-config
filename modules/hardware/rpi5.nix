# Raspberry Pi 5 (bcm2712) hardware configuration.
# Provides board selection, cgroup kernel parameters, and overlay support.
# Import this module in any Pi5 host configuration.
{ inputs, ... }:

{
  raspberry-pi-nix.board = "bcm2712";

  # cgroup v1 memory subsystem required by k3s (and container runtimes generally)
  boot.kernelParams = [
    "cgroup_memory=1"
    "cgroup_enable=memory"
    "cgroup_enable=cpuset"
  ];

  # Note: hardware.raspberry-pi."5".apply-overlays-dtmerge is needed for PCIe/NVMe
  # but is not available at the current nixos-hardware pin. Re-enable in Phase B
  # when NVMe passthrough is configured for Longhorn storage.

  imports = [ inputs.nixos-hardware.nixosModules.raspberry-pi-5 ];
}
