# Data Model: Gibson NixOS Desktop Onboarding

**Date**: 2026-05-18 | **Branch**: `002-gibson-nixos-onboard`

## Entities

### Host: Gibson

| Attribute | Value |
|-----------|-------|
| Hostname | `gibson` |
| Architecture | `x86_64-linux` |
| CPU | AMD Ryzen 9 5950X |
| GPU | NVIDIA RTX 3080 (Ampere) |
| RAM | 64GB |
| Operator | eaglerock (Peter Marks) |
| Groups | wheel, networkmanager, docker |

### Drive Map

| Drive | Type | Size | Filesystem | Mount Point | Format? | Mount Options |
|-------|------|------|------------|-------------|---------|---------------|
| NVMe (new) | NVMe | 2TB | ext4 | `/` (root) | YES | defaults |
| NVMe (new) | NVMe | 2TB | vfat | `/boot` (EFI) | YES | umask=0077 |
| NVMe (new) | NVMe | 2TB | swap | (swap) | YES | — |
| NVMe (Ubuntu) | NVMe | 1TB | ext4 (assumed) | `/mnt/ubuntu` | NO | nofail |
| NVMe (games) | NVMe | 1TB | XFS | `/srv` | NO | nofail |
| HDD (storage) | SATA | varies | varies | `/mnt/hdd` | NO | nofail |

All non-root mounts use `by-uuid` identifiers. Drives may be physically relocated between slots.

### Monitor Layout

| Position | Size | Resolution | i3 Output | Workspaces |
|----------|------|------------|-----------|------------|
| Left | 24" | 1920x1080 | TBD (install) | 3 (Firefox), 9 (spare) |
| Center | 27" | 2560x1440 | TBD (install) | 1, 2, 5, 6, 7, 8 |
| Right | 24" | 1920x1080 | TBD (install) | 4 (Discord), 10 (spare) |

Output names (e.g., DP-0, DP-1, HDMI-0) discovered via `xrandr` during install.

### Gaming Peripherals

| Device | Connection | Driver | NixOS Option |
|--------|-----------|--------|--------------|
| Xbox One controller | USB primary, BT secondary | xpadneo (hid_xpadneo) | `hardware.xpadneo.enable = true` |
| Logitech joysticks | USB | hid-logitech + joydev (auto) | None needed |
| Logitech G29 wheel | USB | new-lg4ff (hid-logitech-new) | `hardware.new-lg4ff.enable = true` |

### Host Profile (extraSpecialArgs)

| Key | Silicon | Gibson |
|-----|---------|--------|
| `hasBattery` | `true` | `false` |
| `wlanInterface` | `"wlp0s20f3"` | TBD (install) |
| `ethInterface` | `""` | TBD (install) |
| `defaultMonitor` | `"eDP-1"` | TBD (install) |

## Module Relationships

### New Files

| File | Purpose | Imports From |
|------|---------|-------------|
| `hosts/gibson/configuration.nix` | Gibson host config | workstation.nix, grub.nix, desktop-ui.nix, gaming.nix, gibson.nix, hardware-configuration.nix |
| `hosts/gibson/hardware-configuration.nix` | Auto-generated hardware probe | — |
| `modules/hardware/gibson.nix` | NVIDIA GPU, AMD CPU, desktop thermals | — |
| `modules/home/i3-gibson.nix` | Triple-monitor i3 config | colors.nix |
| `modules/home/i3-laptop.nix` | Laptop i3 config (renamed from i3.nix) | colors.nix |
| `home/eaglerock-gibson.nix` | Gibson user home-manager entry | workstation-gibson.nix |
| `modules/home/workstation-gibson.nix` | Gibson workstation module chain | base.nix, ui.nix, i3-gibson.nix, polybar.nix, dunst.nix, dev.nix, vscode.nix |

### Modified Files

| File | Change |
|------|--------|
| `flake.nix` | Add `nixosConfigurations.gibson`, unfree allowlist entries |
| `modules/home/polybar.nix` | Parameterize with `hostProfile` (monitor, network, battery) |
| `modules/home/workstation.nix` | Rename i3.nix import to i3-laptop.nix |
| `modules/hosts/gaming.nix` | Add peripheral options (xpadneo, new-lg4ff, udev rules) |
