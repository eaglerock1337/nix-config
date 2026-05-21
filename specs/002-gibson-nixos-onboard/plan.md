# Implementation Plan: Gibson NixOS Desktop Onboarding

**Branch**: `002-gibson-nixos-onboard` | **Date**: 2026-05-21 | **Spec**: `specs/002-gibson-nixos-onboard/spec.md`
**Input**: Feature specification from `specs/002-gibson-nixos-onboard/spec.md`

## Summary

Onboard Gibson (Ryzen 9 5950X / RTX 3080 desktop) onto NixOS from the same
flake as Silicon, with NVIDIA GPU support, triple-monitor i3, GRUB dual-boot
with Ubuntu, and gaming peripherals. Repo restructured using a copy-first,
dedup-later strategy: Phase 2 moves files and creates independent module copies
for Gibson (Silicon MUST be an effective no-op throughout); Phase 7 deduplicates
into common.nix + host variants.

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable flake)
**Primary Dependencies**: nixpkgs 25.11, home-manager 25.11, nixos-hardware, disko, sops-nix
**Storage**: Declarative filesystem config (fileSystems, swapDevices in NixOS modules)
**Testing**: `make dry-run HOST=<host>` for build validation; operator visual spot checks for UI
**Target Platform**: x86_64-linux (Gibson desktop, Silicon laptop)
**Project Type**: NixOS system configuration (declarative infrastructure)
**Performance Goals**: N/A — configuration project, not runtime service
**Constraints**: Silicon MUST remain unchanged throughout (Principle IX). Agents MUST NOT run raw nix commands (Principle VII). RPi/cluster configs immutable in content.
**Scale/Scope**: 2 workstation hosts + 12 cluster nodes in flake; this spec targets Gibson only

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | All Gibson config expressed in Nix modules |
| II. Reproducibility via Flakes | ✅ PASS | Gibson added to existing flake; no new unfenced fetches |
| III. Modular Design | ✅ PASS | Phase 2 uses independent copies (temporary duplication allowed by phased deferral clause); Phase 7 deduplicates |
| IV. Safety-First Changes | ✅ PASS | `make dry-run` before every apply; `build-vm` for boot/GRUB changes |
| V. Pragmatic Phasing | ✅ PASS | Phase 2 duplication is a deliberate temporary workaround; dedup in Phase 7 |
| VI. Minimal & Explicit Footprint | ✅ PASS | Only packages needed for Gibson hardware; unfree allowlist additions documented |
| VII. Standardized Build & Test | ✅ PASS | All validation via Makefile targets; no raw nix commands from agents |
| VIII. Human-AI Collaboration | ✅ PASS | Single stakeholder; technical vocabulary throughout |
| IX. Blast-Radius Isolation | ✅ PASS | `make dry-run HOST=silicon` after every Phase 2 commit; ~10 operator visual checkpoints; RPi configs content-immutable |

**Unfree additions required**: `nvidia-x11`, `nvidia-settings` — justified by RTX 3080 proprietary driver requirement (FR-012). Commit message must document justification per Principle VI.

## Project Structure

### Documentation (this feature)

```text
specs/002-gibson-nixos-onboard/
├── plan.md              # This file
├── research.md          # Phase 0 output (updated)
├── data-model.md        # Phase 1 output (updated)
├── quickstart.md        # Phase 1 output (updated)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

#### Current structure (pre-Phase 2)

```text
flake.nix                          # Entry point — Silicon + HLC inline helpers
hosts/
├── silicon/                       # Silicon host config
│   ├── configuration.nix
│   └── hardware-configuration.nix
└── hlc-*/                         # 12 cluster node configs
modules/
├── hosts/                         # NixOS modules (→ modules/nixos/)
│   ├── common.nix
│   ├── workstation.nix
│   ├── desktop-ui.nix
│   ├── gaming.nix
│   ├── grub.nix
│   └── grub/                      # GRUB theme assets
├── cluster/                       # Cluster modules (→ modules/nixos/server/)
│   ├── common.nix
│   ├── motd.nix
│   ├── prompt.nix
│   └── hlc/                       # HLC submodules
├── hardware/                      # Hardware modules
│   ├── x1-carbon.nix
│   ├── rpi4.nix                   # → hardware/rpi/
│   ├── rpi5.nix                   # → hardware/rpi/
│   └── rpi-eeprom.nix             # → hardware/rpi/
├── home/                          # Home-manager modules
│   ├── base.nix, colors.nix       # Shared (stay)
│   ├── workstation.nix, server.nix # Entry points (stay)
│   ├── i3.nix                     # → workstation/i3/laptop.nix (rename)
│   ├── polybar.nix                # → workstation/polybar-laptop.nix (rename)
│   ├── dunst.nix, ui.nix, dev.nix, vscode.nix  # → workstation/
│   ├── dotfiles/, themes/         # Shared (stay)
│   ├── layouts/, scripts/         # → workstation/
│   └── (no workstation/ subdir yet)
├── k8s/prereqs.nix                # → modules/nixos/k8s.nix
├── sd/                            # → modules/hardware/rpi/sd/
├── shell/                         # → modules/nixos/shell/
└── users/operator.nix             # → modules/nixos/operator.nix
home/
├── eaglerock.nix                  # Shared workstation entry point
└── bob.nix                        # Cluster user
```

#### Target structure (after Phase 2, before Phase 7 dedup)

```text
flake.nix                          # Silicon + Gibson + HLC (via lib/hlc.nix)
lib/
└── hlc.nix                        # Extracted HLC helper functions
hosts/
├── silicon/                       # Unchanged
├── gibson/                        # NEW — Gibson host config
│   ├── configuration.nix
│   └── hardware-configuration.nix # Generated during install
└── hlc-*/                         # Unchanged (content-immutable moves)
modules/
├── nixos/                         # Renamed from modules/hosts/
│   ├── common.nix                 # Content unchanged
│   ├── workstation.nix            # Content unchanged (custom.hostProfile added in Phase 7)
│   ├── operator.nix               # Was modules/users/operator.nix
│   ├── k8s.nix                    # Was modules/k8s/prereqs.nix
│   ├── shell/                     # Was modules/shell/
│   ├── workstation/               # Was flat in modules/hosts/
│   │   ├── desktop-ui.nix
│   │   ├── gaming.nix
│   │   ├── grub.nix
│   │   └── grub/
│   └── server/                    # Was modules/cluster/
│       ├── common.nix (was cluster/common.nix)
│       ├── motd.nix
│       ├── prompt.nix
│       └── hlc/
├── hardware/
│   ├── x1-carbon.nix              # Unchanged
│   ├── gibson.nix                 # NEW — NVIDIA, AMD, PipeWire 5.1
│   └── rpi/                       # Grouped RPi hardware
│       ├── rpi4.nix
│       ├── rpi5.nix
│       ├── rpi-eeprom.nix
│       └── sd/                    # Was modules/sd/
├── home/
│   ├── base.nix, colors.nix       # Shared (unchanged)
│   ├── workstation.nix            # Updated imports
│   ├── server.nix                 # Unchanged
│   ├── dotfiles/, themes/         # Shared (unchanged)
│   └── workstation/
│       ├── i3/
│       │   ├── laptop.nix         # Silicon's i3 — CONTENT UNCHANGED (renamed from i3.nix)
│       │   └── gibson.nix         # Independent copy, adapted for Gibson
│       ├── polybar-laptop.nix     # Silicon's polybar — CONTENT UNCHANGED (renamed)
│       ├── polybar-gibson.nix     # Independent copy, adapted for Gibson
│       ├── dunst.nix              # Content unchanged
│       ├── ui.nix                 # Content unchanged
│       ├── dev.nix                # Content unchanged
│       ├── vscode.nix             # Content unchanged
│       ├── layouts/               # Content unchanged
│       └── scripts/               # Content unchanged
home/
├── eaglerock.nix                  # Shared — unchanged
└── bob.nix                        # Unchanged
```

#### Target structure (after Phase 7 dedup — end state)

Same as above but:
- `workstation/i3/common.nix` — extracted shared config
- `workstation/i3/laptop.nix` — reduced to Silicon-specific delta
- `workstation/i3/gibson.nix` — reduced to Gibson-specific delta
- `workstation/polybar.nix` — single parameterized module (reads `osConfig.custom.hostProfile`)
- Other duplicated modules deduplicated similarly (operator decides per-module)

**Structure Decision**: NixOS declarative config — no src/tests directories.
Module directories organized by concern: `modules/nixos/` for NixOS system
modules, `modules/home/` for home-manager modules, `modules/hardware/` for
hardware-specific modules, `lib/` for pure helper functions.

## Phase Structure

| Phase | Name | Depends On | Description |
|-------|------|------------|-------------|
| 1 | Gibson Scaffold | — | Minimal Gibson host config; `make dry-run HOST=gibson` passes |
| 2 | Repo Restructure | 1 | 10 move groups with Silicon verification checkpoints |
| 3 | Gibson Boot & Storage | 2 | Filesystem mounts, GRUB dual-boot, NVIDIA drivers, suspend, NetworkManager |
| 4 | Gibson i3 Desktop | 2 | Triple-monitor xrandr, workspace assignment, polybar |
| 5 | Gaming Peripherals | 2 | xpadneo, new-lg4ff, udev rules, Steam |
| 6 | Audio Verification | 2 | PipeWire 5.1 surround verification |
| 7 | Code Deduplication | 2, 4 (i3/polybar dedup) | Extract common.nix, parameterize polybar. hostProfile options MAY parallel 4-6; i3/polybar dedup requires Phase 4 |
| 8 | Polish | 3-7 | Final validation, CLAUDE.md update, cleanup |

## Phase 1: Gibson Scaffold

**Goal**: Minimum config so `make dry-run HOST=gibson` passes. No hardware-specific
config yet — just enough to add Gibson to the flake.

**Files created**:
- `hosts/gibson/configuration.nix` — imports existing `modules/hosts/workstation.nix`,
  `grub.nix`, `desktop-ui.nix`, `gaming.nix`. Placeholder `hardware-configuration.nix`
  import (stub until real hardware scan). Sets hostname, operator, stateVersion.
- `hosts/gibson/hardware-configuration.nix` — stub with minimal filesystem config
  (enough to evaluate). Real values filled during install.
- `modules/hardware/gibson.nix` — NVIDIA driver config (FR-012), AMD microcode,
  no laptop power management. PipeWire 5.1 surround config.

**Files modified**:
- `flake.nix` — add `nixosConfigurations.gibson` entry. Uses same pattern as
  silicon (nixpkgs.lib.nixosSystem). Unfree allowlist adds `nvidia-x11`,
  `nvidia-settings`.

**Verification**:
- `make dry-run HOST=gibson` passes
- `make dry-run HOST=silicon` produces identical store path (Principle IX)

## Phase 2: Repo Restructure

**Goal**: Reorganize module directories per FR-020–FR-024. Each move is an
atomic commit with content unchanged. Gibson gets independent copies of UI
modules (FR-014, FR-015, FR-028, FR-029).

### Move Group 1: NixOS Module Moves

**Moves**:
- `modules/hosts/` → `modules/nixos/`
- `modules/hosts/common.nix` → `modules/nixos/common.nix`
- `modules/hosts/workstation.nix` → `modules/nixos/workstation.nix`
- `modules/hosts/desktop-ui.nix` → `modules/nixos/workstation/desktop-ui.nix`
- `modules/hosts/gaming.nix` → `modules/nixos/workstation/gaming.nix`
- `modules/hosts/grub.nix` → `modules/nixos/workstation/grub.nix`
- `modules/hosts/grub/` → `modules/nixos/workstation/grub/`

**Import path updates** (same commit per move):
- `hosts/silicon/configuration.nix` — update all `../../modules/hosts/` → `../../modules/nixos/`
- `hosts/gibson/configuration.nix` — same
- `modules/nixos/workstation.nix` — update `./common.nix` (unchanged — relative path still works)

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: Operator logs into Silicon. Check: i3 starts, workspaces
respond to Super+1-9, polybar visible, alacritty launches. These are most at
risk because `workstation.nix` is the root NixOS module for Silicon's desktop.

### Move Group 2: Cluster/Server Module Moves

**Moves**:
- `modules/cluster/` → `modules/nixos/server/`
- `modules/cluster/common.nix` → `modules/nixos/server/common.nix`
- `modules/cluster/motd.nix` → `modules/nixos/server/motd.nix`
- `modules/cluster/prompt.nix` → `modules/nixos/server/prompt.nix`
- `modules/cluster/hlc/` → `modules/nixos/server/hlc/`

**Import path updates**:
- `flake.nix` — `clusterModule` path: `./modules/cluster/hlc/default.nix` → `./modules/nixos/server/hlc/default.nix` (and provision.nix)
- `modules/nixos/server/hlc/default.nix` — `../common.nix` still works (relative)
- `modules/nixos/server/common.nix` — imports from `../k8s/prereqs.nix` will break if k8s not yet moved; sequence carefully

**Content**: Byte-identical. RPi/cluster configs are immutable (FR-027).

**Verification**: `make dry-run HOST=silicon` + `make dry-run HOST=hlc-501` (spot check one cluster node)
**Visual spot check**: Operator confirms Silicon still launches normally. Focus:
polybar network modules, dunst notifications (cluster module moves shouldn't
affect Silicon, but verify imports didn't break).

### Move Group 3: Misc NixOS Module Moves

**Moves**:
- `modules/k8s/prereqs.nix` → `modules/nixos/k8s.nix`
- `modules/shell/` → `modules/nixos/shell/`
- `modules/users/operator.nix` → `modules/nixos/operator.nix`

**Import path updates**:
- `modules/nixos/common.nix` — update imports for shell/, operator.nix
- `modules/nixos/server/common.nix` — update k8s import path

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: Open terminal on Silicon. Check: shell prompt renders
correctly (Gruvbox colors, git integration), `docker` command available, user
groups correct. Shell modules and operator.nix directly affect the terminal
experience.

### Move Group 4: Hardware Module Moves

**Moves**:
- `modules/hardware/rpi4.nix` → `modules/hardware/rpi/rpi4.nix`
- `modules/hardware/rpi5.nix` → `modules/hardware/rpi/rpi5.nix`
- `modules/hardware/rpi-eeprom.nix` → `modules/hardware/rpi/rpi-eeprom.nix`
- `modules/sd/` → `modules/hardware/rpi/sd/`

**Import path updates**:
- `flake.nix` — SD bootstrap paths (`./modules/sd/bootstrap.nix` → `./modules/hardware/rpi/sd/bootstrap.nix`)
- `modules/hardware/rpi/sd/recovery-utils.nix` — cluster import path update
- Host configs importing rpi4/rpi5 modules — update paths

**Content**: Byte-identical (FR-027).

**Verification**: `make dry-run HOST=silicon` + `make dry-run HOST=hlc-501`
**Visual spot check**: Silicon desktop — no expected visual impact from hardware
module moves (x1-carbon.nix not moved). Quick check: i3 launches, monitor
resolution correct. Minimal risk group.

### Move Group 5: Home-Manager Shared Module Moves

**Moves**:
- `modules/home/dunst.nix` → `modules/home/workstation/dunst.nix`
- `modules/home/ui.nix` → `modules/home/workstation/ui.nix`
- `modules/home/dev.nix` → `modules/home/workstation/dev.nix`
- `modules/home/vscode.nix` → `modules/home/workstation/vscode.nix`
- `modules/home/layouts/` → `modules/home/workstation/layouts/`
- `modules/home/scripts/` → `modules/home/workstation/scripts/`

**Import path updates**:
- `modules/home/workstation.nix` — all import paths updated

**Content**: Byte-identical. `colors.nix` import paths within moved files update
from `./colors.nix` to `../colors.nix`.

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: **HIGH RISK GROUP**. Check on Silicon: alacritty
transparency/colors, dunst notification popup (send test notification), i3
theming (gaps, borders, colors), VS Code launches, picom compositing (window
shadows, transparency). These modules directly control Silicon's visual
appearance.

### Move Group 6: i3 Duplication for Gibson

**Actions**:
- Rename `modules/home/i3.nix` → `modules/home/workstation/i3/laptop.nix` (content unchanged)
- Copy `modules/home/workstation/i3/laptop.nix` → `modules/home/workstation/i3/gibson.nix`

**Import path updates**:
- `modules/home/workstation.nix` — remove i3 import (was `./i3.nix`); shared entry point must not import host-specific modules
- `hosts/silicon/configuration.nix` — add `../../modules/home/workstation/i3/laptop.nix` to `home-manager.users.eaglerock.imports`
- `hosts/gibson/configuration.nix` — add `../../modules/home/workstation/i3/gibson.nix` to `home-manager.users.eaglerock.imports`

**Note**: Gibson's copy is a full standalone i3 config at this point. Gibson-specific
modifications (triple-monitor xrandr, glx picom, workspace assignments) happen
in Phase 4. Host-specific i3 variants are wired here (not deferred to MG9) to
avoid workstation.nix importing a laptop-specific module that Gibson would inherit.

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: **HIGHEST RISK GROUP**. This is the exact change type
that broke Silicon before. Check: all i3 keybindings (Super+1-9, Super+Enter,
Super+d), workspace switching, window movement, floating toggle, resize mode,
i3bar/polybar visible, picom compositing (transparency, shadows), scratchpad
(Super+minus). Test workspace layout restoration on ws 1.

### Move Group 7: Polybar Duplication for Gibson

**Actions**:
- Rename `modules/home/polybar.nix` → `modules/home/workstation/polybar-laptop.nix` (content unchanged)
- Copy → `modules/home/workstation/polybar-gibson.nix`

**Import path updates**:
- `modules/home/workstation.nix` — remove polybar import (was `./polybar.nix`); shared entry point must not import host-specific modules
- `hosts/silicon/configuration.nix` — add `../../modules/home/workstation/polybar-laptop.nix` to `home-manager.users.eaglerock.imports`
- `hosts/gibson/configuration.nix` — add `../../modules/home/workstation/polybar-gibson.nix` to `home-manager.users.eaglerock.imports`

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: Check polybar on Silicon: all modules rendering (battery,
wifi, CPU, memory, workspaces, date/time, volume), click actions work, correct
colors. Polybar is the second most visually impactful module.

### Move Group 8: Remaining Home Module Duplications

**Actions**: For each module that Gibson may customize differently from Silicon,
create an independent copy. Candidates:
- Picom config (if separate from i3 — check ui.nix)
- Any other module where Gibson needs different behavior

**Note**: Most home modules (dunst, dev, vscode) are likely identical between
hosts. Only duplicate modules where Gibson needs different config. Modules
that stay shared are imported via the common workstation.nix path.

**Verification**: `make dry-run HOST=silicon` — identical store path
**Visual spot check**: Check alacritty (font, colors, transparency), dunst
(notification styling), GTK theme. Low risk — most modules unchanged.

### Move Group 9: Flake.nix Changes

**Actions**:
- Extract HLC helpers to `lib/hlc.nix` (FR-013, R-009)
- Update `flake.nix` to import and use `lib/hlc.nix`
- Add `nixosConfigurations.gibson` entry (if not already from Phase 1)

**Note**: i3/polybar host wiring already handled in MG6/MG7. `custom.hostProfile`
options deferred to Phase 7 — only needed for polybar parameterization.

**Verification**: `make dry-run HOST=silicon` — identical store path. `make dry-run HOST=gibson` passes.
**Visual spot check**: Full Silicon desktop check. This group changes flake.nix
directly. Check: everything from groups 5-7 plus login (LightDM), full session startup.

### Move Group 10: Final Full Validation

**Actions**: No new moves. Full validation of both hosts.

**Verification**:
- `make dry-run HOST=silicon` — identical store path to pre-Phase-2 baseline
- `make dry-run HOST=gibson` — passes
- `make dry-run HOST=hlc-501` — spot check one cluster node (content-immutable)

**Visual spot check**: Complete Silicon desktop validation. Operator runs full
daily workflow: terminal, browser, VS Code, workspace switching, multi-monitor
(if available), notifications, lock screen.

## Phase 3: Gibson Boot & Storage

**Goal**: Gibson-specific hardware config for boot, storage, and base system (US1, US3).

**Files modified**:
- `hosts/gibson/hardware-configuration.nix` — real values from `nixos-generate-config`
- `hosts/gibson/configuration.nix` — filesystem mounts (FR-002, FR-003), by-uuid identifiers, nofail on non-root; suspend-to-RAM config (FR-025); NetworkManager for wired ethernet + WiFi (FR-016)
- `modules/nixos/workstation/grub.nix` or `hosts/gibson/configuration.nix` — GRUB + os-prober for dual-boot (FR-004). Include manual GRUB menu entry for Ubuntu as fallback if os-prober fails to detect it
- `modules/hardware/gibson.nix` — NVIDIA fallback: ensure `hardware.nvidia.open = false` and kernel console (nouveau/fbdev) available so system boots to TTY if proprietary driver fails

**Operator actions**: Manual NixOS install on Gibson (partition, format, install).
Discover UUIDs, GPU output names, network interfaces (record `xrandr --query` and `ip link` output for Phase 4).

**Verification**: `make dry-run HOST=gibson` passes. Boot Gibson, verify mounts,
GRUB menu, Ubuntu bootable. After successful NixOS install, update Constitution
Principle VII host table — Gibson now has NixOS (`nixos-rebuild` available),
removing the Ubuntu-era "NixOS not yet installed" restriction.

## Phase 4: Gibson i3 Desktop

**Goal**: Triple-monitor i3 with workspace assignments and polybar (US2).

**Files modified**:
- `modules/home/workstation/i3/gibson.nix` — triple-monitor xrandr, workspace-to-monitor
  mapping (FR-005), directional movement keybindings (FR-006), glx picom, startup layout (FR-019)
- `modules/home/workstation/polybar-gibson.nix` — no battery module, Gibson network
  interfaces, correct default monitor (FR-007)
- `assets/wallpaper-gibson.png` — copy from Silicon's wallpaper as starting point

**Note**: i3/gibson.nix and polybar-gibson.nix already wired to Gibson's
configuration.nix in Phase 2 MG6/MG7. Phase 4 only customizes their content.

**Verification**: `make dry-run HOST=silicon` unchanged. `make dry-run HOST=gibson` passes.
Apply on Gibson, verify all three monitors, workspace navigation, polybar.
Verify Gruvbox Dark theme consistent across i3, polybar, GTK, terminal, lock screen (FR-017).

## Phase 5: Gaming Peripherals

**Goal**: Xbox controller, joysticks, G29 wheel with force feedback (US4).

**Files modified**:
- `modules/nixos/workstation/gaming.nix` — add `hardware.xpadneo.enable` (FR-008),
  `hardware.new-lg4ff.enable` (FR-010), udev rules (FR-011)
- `hosts/gibson/configuration.nix` — Steam config if not already in gaming.nix

**Note**: gaming.nix is shared — changes here affect Silicon too. Phase 5 is
approved for Silicon derivation changes from peripheral enablement (xpadneo,
new-lg4ff add kernel modules even without hardware present). If the derivation
changes, this is acceptable but operator MUST visually validate Silicon after
applying. If changes are unacceptable, refactor to Gibson-only module.

**Verification**: `make dry-run HOST=silicon` — check for derivation changes.
Apply on Gibson, test each peripheral. Operator visual spot check on Silicon
after gaming.nix changes — verify desktop, peripherals, no regressions.

## Phase 6: Audio & System Verification

**Goal**: Verify PipeWire 5.1 surround config (created in Phase 1 scaffold).
Suspend-to-RAM and NetworkManager are configured in Phase 3 alongside boot/storage.

**Files modified**:
- `modules/hardware/gibson.nix` — verify PipeWire WirePlumber surround profile
  and NVIDIA HDMI sink deprioritization (config created in Phase 1, T003)

**Verification**: `make dry-run HOST=silicon` unchanged. Apply on Gibson, test
5.1 audio output via `speaker-test -c 6`, verify microphone input.

## Phase 7: Code Deduplication

**Goal**: Extract shared logic from duplicated modules into common.nix + host
deltas (FR-014b, FR-015b, FR-030). Runs in parallel with Phases 4-6.

**Prerequisites** (before polybar dedup):
- Add `custom.hostProfile` NixOS options to `modules/nixos/workstation.nix` — `hasBattery`, `wlanInterface`, `ethInterface`, `defaultMonitor`
- Set `custom.hostProfile` values in `hosts/silicon/configuration.nix` and `hosts/gibson/configuration.nix`

**Modules to deduplicate**:
- `i3/laptop.nix` + `i3/gibson.nix` → `i3/common.nix` + reduced variants
- `polybar-laptop.nix` + `polybar-gibson.nix` → single `polybar.nix` with `osConfig.custom.hostProfile`
- Picom, dunst, others — operator decides per-module

**Process per module**:
1. Diff laptop vs gibson variant
2. Extract shared lines into common.nix
3. Reduce each variant to host-specific delta
4. `make dry-run HOST=silicon` — identical store path
5. `make dry-run HOST=gibson` — passes
6. Operator visual check on Silicon

**Escape hatch**: If dedup for a specific module is too messy, agent asks
operator whether to keep independent copies. Operator's judgment call.

**Verification**: Both hosts build identically to their pre-dedup state.
Silicon visual spot check after each module dedup.

## Phase 8: Polish

**Goal**: Final validation, documentation, cleanup.

**Actions**:
- Full `make dry-run` for all hosts (silicon, gibson, hlc-501 spot check)
- Update CLAUDE.md agent context (directory structure, build commands, Gibson host)
- Verify Constitution Principle VII table update from T131 is accurate for final state
- Verify quickstart.md is accurate
- Tag commit for release gate

**Verification**: Operator runs full daily workflow on both Silicon and Gibson.

## Complexity Tracking

| Item | Why | Simpler Alternative Rejected Because |
|------|-----|-------------------------------------|
| Phase 2 duplication (Principle III deferral) | Blast-radius isolation for Silicon (Principle IX) | In-place refactoring broke Silicon in prior attempt |
| 10 move groups with visual checkpoints | Regression isolation per atomic commit | Fewer groups = harder to bisect on failure |
| Phase 7 parallel with 4-6 | Dedup is independent of Gibson hardware config | Sequential would delay Gibson usability |
