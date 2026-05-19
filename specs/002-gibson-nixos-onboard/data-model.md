# Data Model: Gibson NixOS Desktop Onboarding

**Date**: 2026-05-19 | **Branch**: `002-gibson-nixos-onboard`

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

### Host Profile (NixOS options via `custom.hostProfile`)

Options defined in `modules/nixos/workstation.nix`, set per-host in `configuration.nix`, read in home-manager via `osConfig.custom.hostProfile.*`.

| Key | Type | Silicon | Gibson |
|-----|------|---------|--------|
| `hasBattery` | bool | `true` | `false` |
| `wlanInterface` | str | `"wlp0s20f3"` | TBD (install) |
| `ethInterface` | str | `""` | TBD (install) |
| `defaultMonitor` | str | `"eDP-1"` | TBD (install) |

i3 variant is NOT part of hostProfile — it's wired via `home-manager.users.eaglerock.imports` in each host's `configuration.nix` (see Import Chains below).

## Module Relationships — Post-Reorg

### Module Directory Mapping (current → target)

| Current Path | Target Path | Type |
|-------------|-------------|------|
| `modules/hosts/common.nix` | `modules/nixos/common.nix` | NixOS (shared) |
| `modules/hosts/workstation.nix` | `modules/nixos/workstation.nix` | NixOS (entry point) |
| `modules/hosts/desktop-ui.nix` | `modules/nixos/workstation/desktop-ui.nix` | NixOS (workstation) |
| `modules/hosts/gaming.nix` | `modules/nixos/workstation/gaming.nix` | NixOS (workstation) |
| `modules/hosts/grub.nix` | `modules/nixos/workstation/grub.nix` | NixOS (workstation) |
| `modules/hosts/grub/` | `modules/nixos/workstation/grub/` | Assets |
| `modules/cluster/common.nix` | `modules/nixos/server.nix` | NixOS (entry point) |
| `modules/cluster/motd.nix` | `modules/nixos/server/motd.nix` | NixOS (server) |
| `modules/cluster/prompt.nix` | `modules/nixos/server/prompt.nix` | NixOS (server) |
| `modules/cluster/hlc/*` | `modules/nixos/server/hlc/*` | NixOS (server) |
| `modules/k8s/prereqs.nix` | `modules/nixos/k8s.nix` | NixOS (shared) |
| `modules/shell/common.nix` | `modules/nixos/shell/common.nix` | NixOS (shared) |
| `modules/shell/utilities.nix` | `modules/nixos/shell/utilities.nix` | NixOS (shared) |
| `modules/users/operator.nix` | `modules/nixos/operator.nix` | NixOS (shared) |
| `modules/hardware/rpi4.nix` | `modules/hardware/rpi/rpi4.nix` | Hardware |
| `modules/hardware/rpi5.nix` | `modules/hardware/rpi/rpi5.nix` | Hardware |
| `modules/hardware/rpi-eeprom.nix` | `modules/hardware/rpi/rpi-eeprom.nix` | Hardware |
| `modules/sd/bootstrap.nix` | `modules/hardware/rpi/sd/bootstrap.nix` | Hardware |
| `modules/sd/recovery-utils.nix` | `modules/hardware/rpi/sd/recovery-utils.nix` | Hardware |
| `modules/home/i3.nix` | `modules/home/workstation/i3/common.nix` + `i3/laptop.nix` | Home (workstation) |
| `modules/home/polybar.nix` | `modules/home/workstation/polybar.nix` | Home (workstation) |
| `modules/home/dunst.nix` | `modules/home/workstation/dunst.nix` | Home (workstation) |
| `modules/home/ui.nix` | `modules/home/workstation/ui.nix` | Home (workstation) |
| `modules/home/vscode.nix` | `modules/home/workstation/vscode.nix` | Home (workstation) |
| `modules/home/dev.nix` | `modules/home/workstation/dev.nix` | Home (workstation) |
| `modules/home/layouts/` | `modules/home/workstation/layouts/` | Assets |
| `modules/home/scripts/` | `modules/home/workstation/scripts/` | Assets |

**Stays in place** (shared): `modules/home/base.nix`, `modules/home/colors.nix`, `modules/home/dotfiles/`, `modules/home/themes/`, `modules/home/workstation.nix`, `modules/home/server.nix`

**New placeholder**: `modules/home/server/.gitkeep` (future server home-manager modules)

### New Files

| File | Purpose | Notes |
|------|---------|-------|
| `hosts/gibson/configuration.nix` | Gibson host config | Imports `modules/nixos/workstation.nix`, `grub.nix`, `desktop-ui.nix`, `gaming.nix`, `modules/hardware/gibson.nix`; sets `custom.hostProfile`; adds i3/gibson.nix to `home-manager.users.eaglerock.imports` |
| `hosts/gibson/hardware-configuration.nix` | Auto-generated hardware probe | Placeholder until `nixos-generate-config` on Gibson |
| `modules/hardware/gibson.nix` | NVIDIA GPU, AMD CPU, PipeWire 5.1 surround | No laptop power management |
| `modules/home/workstation/i3/common.nix` | Shared i3 config (~250 lines) | Keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout |
| `modules/home/workstation/i3/laptop.nix` | Silicon i3 variant | xrandr scaling, brightness keys, xrender picom |
| `modules/home/workstation/i3/gibson.nix` | Gibson i3 variant | Triple-monitor xrandr, glx picom, directional workspace movement |
| `lib/hlc.nix` | HLC helper functions extracted from flake.nix | mkHlcNode, mkHlcProvision, mkHlcBootstrap, mkSdImages, host lists |

### Modified Files (beyond import path updates)

| File | Change |
|------|--------|
| `flake.nix` | Add `nixosConfigurations.gibson`; extract HLC helpers to `lib/hlc.nix`; add unfree `nvidia-x11`, `nvidia-settings` |
| `modules/nixos/workstation.nix` | Define `options.custom.hostProfile` (hasBattery, wlanInterface, ethInterface, defaultMonitor) |
| `modules/home/workstation.nix` | Import path updates: `./workstation/i3/common.nix` replaces `./i3.nix`; other modules under `./workstation/` |
| `modules/home/workstation/polybar.nix` | Parameterize with `osConfig.custom.hostProfile` (monitor, network, battery conditionals); remove picom duplicate |
| `modules/nixos/workstation/gaming.nix` | Add peripheral options (xpadneo, new-lg4ff, udev rules, testing tools) |
| `hosts/silicon/configuration.nix` | Add `custom.hostProfile` values; add i3/laptop.nix to `home-manager.users.eaglerock.imports` |

### Import Chain (Gibson)

```
flake.nix
├── lib/hlc.nix (HLC helpers, host lists)
├── nixosConfigurations.gibson
│   ├── hosts/gibson/configuration.nix
│   │   ├── modules/nixos/workstation.nix (defines custom.hostProfile options)
│   │   │   └── modules/nixos/common.nix
│   │   │       ├── modules/nixos/shell/utilities.nix
│   │   │       ├── modules/nixos/shell/common.nix
│   │   │       └── modules/nixos/operator.nix
│   │   ├── modules/nixos/workstation/grub.nix
│   │   ├── modules/nixos/workstation/desktop-ui.nix
│   │   ├── modules/nixos/workstation/gaming.nix
│   │   ├── modules/hardware/gibson.nix
│   │   ├── hosts/gibson/hardware-configuration.nix
│   │   └── custom.hostProfile = { hasBattery=false; ... }
│   └── home-manager
│       ├── home/eaglerock.nix (shared — same as Silicon)
│       │   └── modules/home/workstation.nix
│       │       ├── modules/home/base.nix
│       │       ├── modules/home/workstation/i3/common.nix (shared i3)
│       │       ├── modules/home/workstation/polybar.nix (reads osConfig.custom.hostProfile)
│       │       ├── modules/home/workstation/dunst.nix
│       │       ├── modules/home/workstation/ui.nix
│       │       ├── modules/home/workstation/dev.nix
│       │       └── modules/home/workstation/vscode.nix
│       └── modules/home/workstation/i3/gibson.nix (via home-manager.users.eaglerock.imports)
```

### Import Chain (Silicon — post-reorg, functionally identical)

```
flake.nix
├── lib/hlc.nix (HLC helpers, host lists)
├── nixosConfigurations.silicon
│   ├── hosts/silicon/configuration.nix
│   │   ├── modules/nixos/workstation.nix (defines custom.hostProfile options)
│   │   │   └── modules/nixos/common.nix
│   │   │       ├── modules/nixos/shell/utilities.nix
│   │   │       ├── modules/nixos/shell/common.nix
│   │   │       └── modules/nixos/operator.nix
│   │   ├── modules/nixos/workstation/grub.nix
│   │   ├── modules/nixos/workstation/desktop-ui.nix
│   │   ├── modules/nixos/workstation/gaming.nix
│   │   ├── modules/hardware/x1-carbon.nix
│   │   ├── hosts/silicon/hardware-configuration.nix
│   │   └── custom.hostProfile = { hasBattery=true; wlanInterface="wlp0s20f3"; defaultMonitor="eDP-1"; }
│   └── home-manager
│       ├── home/eaglerock.nix (shared)
│       │   └── modules/home/workstation.nix
│       │       ├── modules/home/base.nix
│       │       ├── modules/home/workstation/i3/common.nix (shared i3)
│       │       ├── modules/home/workstation/polybar.nix (reads osConfig.custom.hostProfile)
│       │       ├── modules/home/workstation/dunst.nix
│       │       ├── modules/home/workstation/ui.nix
│       │       ├── modules/home/workstation/dev.nix
│       │       └── modules/home/workstation/vscode.nix
│       └── modules/home/workstation/i3/laptop.nix (via home-manager.users.eaglerock.imports)
```
