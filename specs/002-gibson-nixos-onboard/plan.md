# Implementation Plan: Gibson NixOS Desktop Onboarding

**Branch**: `002-gibson-nixos-onboard` | **Date**: 2026-05-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-gibson-nixos-onboard/spec.md`

## Summary

Onboard Gibson (Ryzen 9 5950X / RTX 3080 / 64GB RAM desktop) into the existing NixOS flake. Reuse Silicon's workstation module stack while adding NVIDIA GPU support, triple-monitor i3 layout, multi-disk configuration preserving the Ubuntu install, gaming peripheral drivers, and parameterized polybar. The architecture splits i3 into laptop/desktop variants and introduces `hostProfile` via `extraSpecialArgs` for host-specific polybar differences.

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable)
**Primary Dependencies**: nixpkgs-25.11, home-manager-25.11, NVIDIA driver 580.x (stable branch)
**Storage**: ext4 root (2TB NVMe), XFS games (/srv), existing Ubuntu NVMe, HDD
**Testing**: `nixos-rebuild dry-run --flake .#gibson`, `nix flake check`, manual hardware verification post-install
**Target Platform**: x86_64-linux (Gibson desktop)
**Project Type**: NixOS system configuration (declarative infrastructure)
**Constraints**: Must not break Silicon config; only format the new 2TB NVMe; `by-uuid` for all mounts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative | PASS | All config in Nix modules |
| II. Flakes | PASS | All deps locked in flake.lock |
| III. Modular | PASS | One concern per module — i3 split, gibson.nix hardware, gaming peripherals |
| IV. Safety-First | PASS | dry-run before apply; build-vm for boot/GRUB changes |
| V. Pragmatic Phasing | PASS | GPU output names deferred to install-time discovery (not a workaround) |
| VI. Minimal Footprint | NEEDS ACTION | `nvidia-x11`, `nvidia-settings` must be added to unfree allowlist with commit justification |
| VII. Build & Test | NEEDS UPDATE | Constitution table lists Gibson as Ubuntu build host. Post-install, table must be updated to show NixOS. Pre-install, validate via `nixos-rebuild dry-run --flake .#gibson` on Silicon. |
| VIII. Human-AI | PASS | Single-stakeholder, technical vocabulary |

**Gate violations requiring action**:
- Principle VI: Add unfree entries — justified by hardware requirement (NVIDIA proprietary driver)
- Principle VII: Constitution table update — deferred until Gibson has NixOS installed; not blocking for config development

## Project Structure

### Documentation (this feature)

```text
specs/002-gibson-nixos-onboard/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 research findings (complete)
├── data-model.md        # Phase 1 data model (complete)
└── checklists/
    └── requirements.md  # Spec quality checklist (complete)
```

### Source Code (repository root)

```text
flake.nix                                    # MODIFY: add gibson nixosConfiguration + hostProfile
hosts/
├── silicon/
│   ├── configuration.nix                    # UNCHANGED
│   └── hardware-configuration.nix           # UNCHANGED
└── gibson/
    ├── configuration.nix                    # CREATE: gibson host config
    └── hardware-configuration.nix           # CREATE: generated at install time (placeholder)
modules/
├── hardware/
│   ├── x1-carbon.nix                        # UNCHANGED
│   └── gibson.nix                           # CREATE: NVIDIA + AMD + desktop hardware
├── hosts/
│   ├── common.nix                           # UNCHANGED
│   ├── workstation.nix                      # UNCHANGED
│   ├── desktop-ui.nix                       # UNCHANGED
│   ├── grub.nix                             # UNCHANGED (os-prober added in gibson config)
│   └── gaming.nix                           # MODIFY: add peripheral support
└── home/
    ├── workstation.nix                       # MODIFY: import i3-laptop.nix instead of i3.nix
    ├── workstation-gibson.nix                # CREATE: import i3-gibson.nix instead
    ├── i3.nix → i3-laptop.nix               # RENAME: laptop i3 config
    ├── i3-gibson.nix                         # CREATE: triple-monitor i3 config
    ├── polybar.nix                           # MODIFY: parameterize with hostProfile
    └── colors.nix                            # UNCHANGED
home/
├── eaglerock.nix                            # UNCHANGED (Silicon)
└── eaglerock-gibson.nix                     # CREATE: Gibson user config
```

**Structure Decision**: Follows the existing pattern — host-specific configs in `hosts/<hostname>/`, hardware modules in `modules/hardware/`, home-manager modules in `modules/home/`, per-user entry points in `home/`. The new pattern introduced is per-host workstation modules (`workstation.nix` vs `workstation-gibson.nix`) to select the correct i3 variant.

## Implementation Phases

### Phase 1: Module Architecture Refactoring (US5 — no Gibson-specific code)

Refactor existing modules to support multi-host patterns before adding Gibson-specific config. Silicon must remain identical after this phase.

**1a. Rename i3.nix → i3-laptop.nix**
- Rename `modules/home/i3.nix` to `modules/home/i3-laptop.nix`
- Update `modules/home/workstation.nix` to import `./i3-laptop.nix`
- Verify: `nixos-rebuild dry-run --flake .#silicon` — identical output

**1b. Parameterize polybar.nix**
- Add `hostProfile` to polybar.nix function args
- Replace hardcoded `"wlp0s20f3"` with `hostProfile.wlanInterface`
- Replace hardcoded `eDP-1` fallback with `hostProfile.defaultMonitor`
- Wrap battery module in `lib.optionalAttrs hostProfile.hasBattery`
- Add ethernet module conditionally via `lib.optionalAttrs (hostProfile.ethInterface != "")`
- Add `hostProfile` to `home-manager.extraSpecialArgs` in `flake.nix` for Silicon:
  ```
  hostProfile = { hasBattery = true; wlanInterface = "wlp0s20f3"; ethInterface = ""; defaultMonitor = "eDP-1"; };
  ```
- Verify: `nixos-rebuild dry-run --flake .#silicon` — identical output

**1c. Add gaming peripheral support to gaming.nix**
- Add `hardware.xpadneo.enable = true`
- Add `hardware.new-lg4ff.enable = true`
- Add udev rules for G29 (vendor 046d, product c24f) with `TAG+="uaccess"`
- Add testing tools to system packages: `evtest`, `linuxConsoleTools`, `jstest-gtk`
- These are harmless on Silicon (modules only load when hardware is present)
- Verify: `nixos-rebuild dry-run --flake .#silicon` — builds, no regressions

### Phase 2: Gibson Hardware & Host Config (US1)

**2a. Create modules/hardware/gibson.nix**
- AMD CPU: microcode updates, `kvm-amd` kernel module
- NVIDIA GPU: `services.xserver.videoDrivers = [ "nvidia" ]`, `hardware.nvidia.open = true`, modesetting, power management
- `hardware.graphics.enable = true` + `enable32Bit = true`
- Vulkan packages: `vulkan-loader`, `vulkan-tools`
- No laptop power management (no TLP, no thinkfan, no battery thresholds)
- Desktop packages: `lm_sensors`, `nvtopPackages.nvidia`

**2b. Create hosts/gibson/configuration.nix**
- Hostname: `gibson`
- Operator: eaglerock (same groups as Silicon)
- Imports: workstation.nix, grub.nix, desktop-ui.nix, gaming.nix, gibson.nix, hardware-configuration.nix
- GRUB: enable os-prober for Ubuntu detection
- State version: 25.11
- Unfree allowlist: `nvidia-x11`, `nvidia-settings` (add to existing `claude-code` list)

**2c. Create hosts/gibson/hardware-configuration.nix (placeholder)**
- Placeholder with known drive layout (2TB root, 1TB Ubuntu at /mnt/ubuntu, 1TB XFS at /srv, HDD at /mnt/hdd)
- All mounts use `by-uuid` — actual UUIDs filled during install after partitioning
- `nofail` on non-root mounts
- 32GB swap partition
- AMD CPU microcode
- Kernel modules: `nvme`, `xhci_pci`, `ahci`, `usbhid`, `sd_mod` (initrd); `kvm-amd` (kernel)

**2d. Add gibson to flake.nix**
- New `nixosConfigurations.gibson` entry
- `home-manager.extraSpecialArgs` with Gibson's `hostProfile` (monitor/network TBD at install)
- `home-manager.users.eaglerock = import ./home/eaglerock-gibson.nix`
- Verify: `nix flake check` and `nixos-rebuild dry-run --flake .#gibson` (will warn about placeholder UUIDs but should evaluate)

### Phase 3: Gibson i3 & Desktop (US2)

**3a. Create modules/home/i3-gibson.nix**
- Copy i3-laptop.nix as starting point
- Remove laptop xrandr commands (scaling, DPI)
- Add triple-monitor xrandr (positions TBD, placeholder output names)
- Workspace-to-output assignments: Left = ws 3, 9; Right = ws 4, 10; Center = ws 1, 2, 5, 6, 7, 8
- Add directional keybindings: `$mod+Shift+Left` move workspace to left output, `$mod+Shift+Right` move workspace to right output
- Keep existing `$mod+x` as move-to-next-output
- Same app class assignments as Silicon (Firefox→3, Discord→4, Steam→5, etc.)
- Same startup: workspace 1 layout restore, 3 terminals, scratchpad, polybar restart, picom, wallpaper
- Same Gruvbox colors from colors.nix, same font, same gaps

**3b. Create modules/home/workstation-gibson.nix**
- Copy workstation.nix
- Change i3 import: `./i3-gibson.nix` instead of `./i3-laptop.nix`
- All other imports identical (base.nix, ui.nix, polybar.nix, dunst.nix, dev.nix, vscode.nix)

**3c. Create home/eaglerock-gibson.nix**
- Import `../modules/home/workstation-gibson.nix`
- Same structure as eaglerock.nix

### Phase 4: Dual-Boot GRUB (US3)

**4a. Enable os-prober in Gibson's configuration**
- `boot.loader.grub.useOSProber = true` in hosts/gibson/configuration.nix
- This requires the Ubuntu NVMe to be mounted (or at least its EFI partition visible) at build time
- GRUB timeout and default handled by existing grub.nix module
- Verify: `nixos-rebuild dry-run --flake .#gibson` — evaluates with os-prober enabled

### Phase 5: Verification & Install Prep

**5a. Pre-install verification (on Silicon)**
- `nix flake check` — all configs evaluate
- `nixos-rebuild dry-run --flake .#silicon` — zero regression
- `nixos-rebuild dry-run --flake .#gibson` — evaluates (placeholder UUIDs expected)

**5b. Install procedure (manual, on Gibson)**
- Boot NixOS minimal ISO from USB
- Partition 2TB NVMe: 512MB EFI, 32GB swap, remainder ext4
- `nixos-generate-config --root /mnt` — capture hardware-configuration.nix
- Copy generated hardware-configuration.nix to `hosts/gibson/`
- Fill in real UUIDs for all drives
- Run `xrandr` to discover GPU output names → update i3-gibson.nix
- Discover network interface names → update hostProfile in flake.nix
- `nixos-install --flake .#gibson`
- Reboot, verify GRUB shows NixOS + Ubuntu

**5c. Post-install verification (on Gibson)**
- `nvidia-smi` — RTX 3080 detected
- `lsblk` + `mount` — all drives at correct mount points
- All 3 monitors display content
- Polybar on all monitors, no battery module
- Connect each peripheral, verify with `evtest` / `jstest` / `fftest`
- Boot into Ubuntu from GRUB — verify it still works
- `nixos-rebuild dry-run --flake .#silicon` on Gibson — Silicon config unaffected

## Complexity Tracking

No constitution violations requiring justification. The unfree additions (nvidia-x11, nvidia-settings) are hardware requirements, not complexity choices.
