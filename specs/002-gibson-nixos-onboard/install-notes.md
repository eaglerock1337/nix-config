# Gibson NixOS Install Notes

## NVIDIA + Live USB

Boot the installer with `nomodeset` kernel param (press `e` at GRUB, add to
linux line) if the display is garbled on the RTX 3080. The live environment
uses nouveau which can be flaky on 30-series.

## Partitioning the 2TB NVMe

Only touch the 2TB SSD. Create at minimum two partitions:

- EFI (`/boot`) — ~512MB, vfat
- Root (`/`) — ext4, rest of disk
- Swap (optional) — 32GB, no resume device

**Double-check you're targeting the right drive** (`lsblk` before touching
anything). Other drives (Ubuntu NVMe, games NVMe, HDD) remain untouched.

## hardware-configuration.nix

After partitioning and mounting at `/mnt`, run:

```bash
nixos-generate-config --root /mnt
```

The generated file will have real UUIDs, detected kernel modules, etc.
Replace the stub in `hosts/gibson/hardware-configuration.nix` with those
real values before install.

## Flake Install

Clone the repo (or copy it) in the live environment. Update
hardware-configuration.nix with real values, stage the changes, then:

```bash
git add -A
nixos-install --flake .#gibson
```

## Deferred to Post-Install (Phase 3 Tasks)

Don't worry about these during install — they'll be wired up after booting
into NixOS:

- os-prober / GRUB dual-boot entries (T084, T130)
- Other drive mounts: `/mnt/ubuntu`, `/srv`, `/mnt/hdd` (T083)
- NetworkManager config (T086)
- Suspend-to-RAM (T085)

## Main Risk

Picking the wrong drive during partitioning. Everything else is recoverable.
