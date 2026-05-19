# Implementation Plan: Gibson NixOS Desktop Onboarding

**Branch**: `002-gibson-nixos-onboard` | **Date**: 2026-05-19 | **Spec**: `specs/002-gibson-nixos-onboard/spec.md`
**Input**: Feature specification + Session 2026-05-18/19 clarifications

## Summary

Onboard Gibson (Ryzen 9 5950X / RTX 3080 / 64GB RAM desktop) onto NixOS, reusing Silicon's curated i3 environment. Three major workstreams: (1) module directory reorganization (`modules/hosts/` → `modules/nixos/`, cluster absorption, home module redistribution), (2) Gibson host configuration (NVIDIA drivers, 4-drive mount layout, triple-monitor i3, gaming peripherals), (3) multi-host architecture (i3 split into common/laptop/gibson, polybar parameterization via NixOS options, HLC helper extraction to `lib/hlc.nix`).

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable)
**Primary Dependencies**: nixpkgs 25.11, home-manager release-25.11, nixos-raspberrypi, nixos-hardware, disko, sops-nix
**Storage**: Filesystem declarations (4 drives, by-uuid identifiers)
**Testing**: `nix flake check`, `nixos-rebuild dry-run --flake .#<host>`, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
**Target Platform**: x86_64-linux (Gibson, Silicon), aarch64-linux (HLC Pi cluster — import paths affected by reorg)
**Project Type**: System configuration (NixOS flake)
**Constraints**: Zero regression on Silicon and all 12 HLC node configs; constitution compliance (8 principles)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | All changes are Nix expressions |
| II. Reproducibility via Flakes | ✅ PASS | Using flake.nix, all deps locked |
| III. Modular Design | ✅ PASS | Reorg improves compliance — clearer separation, i3 split into common/variant |
| IV. Safety-First Changes | ✅ PASS | Dry-run before apply; reorg validated via `nix flake check` + dry-run of silicon + HLC spot-check |
| V. Pragmatic Phasing | ✅ PASS | No workarounds needed |
| VI. Minimal & Explicit Footprint | ⚠️ NOTE | New unfree: `nvidia-x11`, `nvidia-settings` — justified by GPU hardware requirement (commit message documents) |
| VII. Standardized Build & Test | ⚠️ NOTE | Constitution host capability table lists Gibson as Ubuntu build host — amendment drafted but NOT applied until Gibson physically has NixOS |
| VIII. Human-AI Collaboration | ✅ PASS | Single stakeholder, technical output |

No violations. Two tracked items (VI unfree additions, VII capability table amendment) resolved during implementation.

## Project Structure

### Documentation (this feature)

```text
specs/002-gibson-nixos-onboard/
├── plan.md              # This file
├── research.md          # Phase 0 output (R-001 through R-009)
├── data-model.md        # Phase 1 output (entities, module mapping, import chains)
├── quickstart.md        # Phase 1 output (install and dev workflow)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
flake.nix                         # Entry point — silicon, gibson, HLC (via lib/hlc.nix)
lib/
└── hlc.nix                       # HLC helpers extracted from flake.nix

hosts/
├── silicon/                      # Existing laptop host
│   ├── configuration.nix         # Modified: import paths, custom.hostProfile, i3/laptop.nix import
│   └── hardware-configuration.nix
├── gibson/                       # NEW: desktop host
│   ├── configuration.nix         # custom.hostProfile, i3/gibson.nix import, os-prober
│   └── hardware-configuration.nix
└── hlc-*/                        # Cluster nodes (import path updates only)

home/
└── eaglerock.nix                 # Shared workstation home entry (imports workstation.nix)

modules/
├── nixos/                        # NixOS system modules (was modules/hosts/ + modules/cluster/)
│   ├── common.nix                # Shared: nix settings, locale, SSH, shell
│   ├── workstation.nix           # Workstation entry: imports common.nix, defines custom.hostProfile options
│   ├── server.nix                # Server entry (was cluster/common.nix)
│   ├── k8s.nix                   # K8s prereqs (was k8s/prereqs.nix)
│   ├── operator.nix              # Operator user (was users/operator.nix)
│   ├── shell/                    # common.nix, utilities.nix (was modules/shell/)
│   ├── workstation/              # desktop-ui.nix, gaming.nix, grub.nix, grub/
│   └── server/                   # motd.nix, prompt.nix, hlc/ (was modules/cluster/)
├── home/                         # Home-manager modules
│   ├── base.nix                  # Shared baseline (neovim, bash, dotfiles)
│   ├── colors.nix                # Gruvbox palette (shared by i3, polybar, dunst)
│   ├── dotfiles/, themes/        # Shared support (referenced by base.nix)
│   ├── workstation.nix           # Workstation entry: imports i3/common.nix + workstation/*
│   ├── server.nix                # Server entry: imports base.nix + tmux
│   ├── server/                   # Future server home modules (.gitkeep)
│   └── workstation/              # Workstation-specific home modules
│       ├── i3/                   # common.nix, laptop.nix, gibson.nix
│       ├── polybar.nix           # Parameterized via osConfig.custom.hostProfile
│       ├── dunst.nix, ui.nix, dev.nix, vscode.nix
│       ├── layouts/, scripts/    # i3 layout files and helper scripts
│       └── (picom removed from ui.nix/polybar.nix — shared in i3/common.nix, backend+vsync in variant files)
└── hardware/                     # Hardware modules
    ├── x1-carbon.nix             # Silicon laptop
    ├── gibson.nix                # NEW: NVIDIA, AMD CPU, PipeWire 5.1
    └── rpi/                      # rpi4.nix, rpi5.nix, rpi-eeprom.nix, sd/
```

**Structure Decision**: NixOS flake configuration — no src/ or tests/ directories. Validation is via `nix flake check` and `nixos-rebuild dry-run`.

## Key Architectural Decisions

### 1. Polybar Parameterization: NixOS Options + osConfig (not extraSpecialArgs)

Per FR-015 and Session 2026-05-19 clarification. `custom.hostProfile` options defined in `modules/nixos/workstation.nix`, set per-host in `configuration.nix`, read in polybar via `osConfig.custom.hostProfile.*`. Type-checked, no flake.nix data bloat.

See: R-003 in research.md

### 2. i3 Split: Subdirectory with Variant via home-manager.users Imports

Per FR-014. Three files in `modules/home/workstation/i3/`:
- `common.nix` — shared keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout (~250 lines)
- `laptop.nix` — Silicon: xrandr scaling, brightness keys, xrender picom
- `gibson.nix` — Gibson: triple-monitor xrandr, glx picom, directional workspace movement

`workstation.nix` imports `i3/common.nix`. Variant imported in each host's `configuration.nix`:
```nix
home-manager.users.eaglerock.imports = [
  ../../modules/home/workstation/i3/laptop.nix  # Silicon
];
```

No dynamic imports, no `hostProfile.i3Variant` string interpolation. See: R-008 in research.md

### 3. HLC Helpers → lib/hlc.nix

Per FR-013 and Session 2026-05-19 clarification. `lib/` follows nixpkgs convention: pure utility functions go in `lib/`, NixOS module-system participants (things with `options`/`config`) go in `modules/`. HLC helpers (`mkHlcNode`, `mkHlcProvision`, `mkHlcBootstrap`, `mkSdImages`, host lists) are builder functions, not modules. flake.nix stays pure composition. See: R-009 in research.md

### 4. Single Shared eaglerock.nix

Per Session 2026-05-19 clarification: `home/eaglerock.nix` is generic for ALL workstations. No `eaglerock-gibson.nix`. Host-specific i3 variant is the only per-host home module, wired via `home-manager.users.eaglerock.imports` in configuration.nix.

### 5. Picom Deduplication

Currently triplicated: `i3.nix`, `polybar.nix`, and `ui.nix` (line 39–44, `services.picom` with `vSync = true`). After split: shared picom settings (`enable`, `fade`, `shadow`) move to `i3/common.nix`; backend + vsync live only in variant files (laptop.nix: xrender/vsync=false, gibson.nix: glx/vsync=true). Removed from both polybar.nix and ui.nix. The ui.nix reconciliation (T010a) MUST happen before the i3 split (T010b) to avoid module-system conflicts on `services.picom.vSync`.

### 6. NVIDIA Driver Package

Per Session 2026-05-19 clarification: `nvidiaPackages.stable` as default in `modules/hardware/gibson.nix`, with a commented `nvidiaPackages.latest` alternative for easy single-line switching. See: R-001 in research.md

### 7. Multi-Monitor Failure Handling

Per Session 2026-05-19 clarification: let i3/xrandr fail gracefully — i3 starts on whatever monitors xrandr succeeds on. No custom retry logic, no autorandr profiles.

## Complexity Tracking

No constitution violations requiring justification.

| Item | Status | Resolution |
|------|--------|------------|
| Unfree nvidia-x11, nvidia-settings | Tracked | Justified by hardware requirement; documented in commit message per Principle VI |
| Constitution VII host table | Tracked | Amendment drafted (T031), applied only after Gibson physical install |
