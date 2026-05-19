# Tasks: Gibson NixOS Desktop Onboarding

**Input**: Design documents from `specs/002-gibson-nixos-onboard/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks grouped by user story. Module reorganization (US5) executes first as foundational work despite being P3 in the spec — it's a prerequisite for clean Gibson onboarding.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1–US5)
- All paths relative to repo root

---

## Phase 1: Setup

**Purpose**: Branch and environment verification

- [ ] T001 Verify branch `002-gibson-nixos-onboard` is clean and up-to-date with main
- [ ] T002 Verify `make flake-check` and `make local-dry` pass on current state (pre-reorg baseline)

**Checkpoint**: Baseline verified — reorg can begin

---

## Phase 2: Foundational — Module Reorganization [US5] (Priority: P3 but blocks all other work)

**Goal**: Reorganize module directory structure per spec FR-020 through FR-024, split i3 into common/variant, define custom.hostProfile NixOS options, parameterize polybar via osConfig. Zero functional change to Silicon — pure restructuring + parameterization.

**⚠️ CRITICAL**: No Gibson-specific work can begin until this phase is complete and validated.

**Independent Test**: `nix flake check` passes; `nixos-rebuild dry-run --flake .#silicon` produces identical closure; HLC node configs evaluate without error.

### Directory creation

- [ ] T003 [US5] Create new directory structure: `lib/`, `modules/nixos/`, `modules/nixos/workstation/`, `modules/nixos/server/`, `modules/nixos/shell/`, `modules/home/workstation/`, `modules/home/workstation/i3/`, `modules/home/server/`, `modules/hardware/rpi/`, `modules/hardware/rpi/sd/`

### HLC extraction

- [ ] T004 [US5] Extract HLC helpers from `flake.nix` to `lib/hlc.nix` — move `mkHlcNode`, `mkHlcProvision`, `mkHlcBootstrap`, `mkSdImages`, `pi4Hosts`, `pi5Hosts` (~80 lines) into a function that receives flake inputs and returns the helper attrset. Update `flake.nix` to `import ./lib/hlc.nix { inherit nixpkgs home-manager ...; }` and merge results. `lib/` is for pure utility functions per nixpkgs convention (not modules). See research.md R-009

### File moves (parallel — each touches different source directories)

- [ ] T005 [P] [US5] Move NixOS system modules: `git mv modules/hosts/common.nix modules/nixos/common.nix`, `git mv modules/hosts/workstation.nix modules/nixos/workstation.nix`, `git mv modules/hosts/desktop-ui.nix modules/nixos/workstation/desktop-ui.nix`, `git mv modules/hosts/gaming.nix modules/nixos/workstation/gaming.nix`, `git mv modules/hosts/grub.nix modules/nixos/workstation/grub.nix`, `git mv modules/hosts/grub/ modules/nixos/workstation/grub/`
- [ ] T006 [P] [US5] Move cluster → server: `git mv modules/cluster/common.nix modules/nixos/server.nix`, `git mv modules/cluster/motd.nix modules/nixos/server/motd.nix`, `git mv modules/cluster/prompt.nix modules/nixos/server/prompt.nix`, `git mv modules/cluster/hlc/ modules/nixos/server/hlc/`
- [ ] T007 [P] [US5] Move misc NixOS modules: `git mv modules/k8s/prereqs.nix modules/nixos/k8s.nix`, `git mv modules/shell/common.nix modules/nixos/shell/common.nix`, `git mv modules/shell/utilities.nix modules/nixos/shell/utilities.nix`, `git mv modules/users/operator.nix modules/nixos/operator.nix`
- [ ] T008 [P] [US5] Move RPi + SD modules: `git mv modules/hardware/rpi4.nix modules/hardware/rpi/rpi4.nix`, `git mv modules/hardware/rpi5.nix modules/hardware/rpi/rpi5.nix`, `git mv modules/hardware/rpi-eeprom.nix modules/hardware/rpi/rpi-eeprom.nix`, `git mv modules/sd/bootstrap.nix modules/hardware/rpi/sd/bootstrap.nix`, `git mv modules/sd/recovery-utils.nix modules/hardware/rpi/sd/recovery-utils.nix`
- [ ] T009 [P] [US5] Move home-manager workstation modules: `git mv modules/home/polybar.nix modules/home/workstation/polybar.nix`, `git mv modules/home/dunst.nix modules/home/workstation/dunst.nix`, `git mv modules/home/ui.nix modules/home/workstation/ui.nix`, `git mv modules/home/vscode.nix modules/home/workstation/vscode.nix`, `git mv modules/home/dev.nix modules/home/workstation/dev.nix`, `git mv modules/home/layouts/ modules/home/workstation/layouts/`, `git mv modules/home/scripts/ modules/home/workstation/scripts/`

### i3 split (depends on T009 — workstation/ dir must exist)

- [ ] T010a [US5] Reconcile picom: `modules/home/ui.nix` (line 39–44) enables `services.picom` with `vSync = true`. i3 variant files set different backends/vsync values — module system WILL error on conflicting definitions. Remove entire `services.picom` block from `ui.nix`. Shared picom settings (`enable`, `fade`, `shadow`) will be placed in `i3/common.nix` during T010b. Backend + vsync live only in variant files (`laptop.nix`: xrender/vsync=false; `gibson.nix`: glx/vsync=true). Must complete before T010b
- [ ] T010b [US5] Split `modules/home/i3.nix` into `modules/home/workstation/i3/common.nix` + `modules/home/workstation/i3/laptop.nix` — extract shared config (~250 lines: keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout with 3 terminals + scratchpad) plus shared picom settings (from T010a) to `common.nix`; Silicon-specific config (xrandr scaling, brightness keys, xrender picom with `backend = "xrender"`, `vsync = false`) to `laptop.nix`. `laptop.nix` does NOT import `common.nix` — both are merged as separate NixOS modules. Remove original `i3.nix` after split. See research.md R-008

### Import path updates (must run after all file moves + i3 split)

- [ ] T011 [US5] Update import paths in `modules/nixos/` files: `common.nix` — `../shell/` → `./shell/`, `../users/operator.nix` → `./operator.nix`; `server.nix` — `../hosts/common.nix` → `./common.nix`, `./motd.nix` → `./server/motd.nix`, `./prompt.nix` → `./server/prompt.nix`, `../k8s/prereqs.nix` → `./k8s.nix`; `server/hlc/default.nix` — `../common.nix` → `../../server.nix`; `server/hlc/provision.nix` — `../../users/operator.nix` → `../../operator.nix`; `hardware/rpi/sd/recovery-utils.nix` — cluster path → `../../nixos/server/hlc/hlc-recover-script.nix`
- [ ] T012 [US5] Update import paths in home, host, and flake files: `modules/home/workstation.nix` — change imports to `./workstation/i3/common.nix`, `./workstation/polybar.nix`, `./workstation/dunst.nix`, `./workstation/ui.nix`, `./workstation/dev.nix`, `./workstation/vscode.nix`; `modules/home/workstation/dunst.nix` — `./colors.nix` → `../colors.nix`; `modules/home/workstation/polybar.nix` — `./colors.nix` → `../colors.nix`; `hosts/silicon/configuration.nix` — `../../modules/hosts/` → `../../modules/nixos/` for all imports, `grub.nix` → `workstation/grub.nix`, `desktop-ui.nix` → `workstation/desktop-ui.nix`, `gaming.nix` → `workstation/gaming.nix`; add `../../modules/home/workstation/i3/laptop.nix` to `home-manager.users.eaglerock.imports`; all 12 `hosts/hlc-*/configuration.nix` — update RPi hardware module paths to `../../modules/hardware/rpi/rpi4.nix` or `rpi5.nix`; `flake.nix` — update cluster/sd paths to new locations under `modules/nixos/server/` and `modules/hardware/rpi/sd/` (note: some of these are now in `lib/hlc.nix` after T004)
- [ ] T013 [US5] Update comments and documentation referencing old paths, remove empty old directories: `modules/hosts/`, `modules/cluster/`, `modules/k8s/`, `modules/sd/`, `modules/shell/`, `modules/users/`. Create `modules/home/server/.gitkeep` placeholder

### custom.hostProfile + polybar parameterization

- [ ] T014 [US5] Define `custom.hostProfile` NixOS options in `modules/nixos/workstation.nix` — `hasBattery` (bool, default false), `wlanInterface` (str, default ""), `ethInterface` (str, default ""), `defaultMonitor` (str, default "eDP-1"). Set Silicon values in `hosts/silicon/configuration.nix`: `hasBattery = true`, `wlanInterface = "wlp0s20f3"`, `defaultMonitor = "eDP-1"`. See research.md R-003
- [ ] T015 [US5] Parameterize `modules/home/workstation/polybar.nix` with `osConfig.custom.hostProfile` — add `osConfig` to function args, use `lib.optionals osConfig.custom.hostProfile.hasBattery` for battery module, use `osConfig.custom.hostProfile.wlanInterface` for WiFi module, add ethernet module when `ethInterface != ""`, use `osConfig.custom.hostProfile.defaultMonitor` for bar monitor. Remove picom config from polybar (picom now lives only in i3 variant files). See research.md R-003

### Validation

- [ ] T016 [US5] Validate module reorganization: run `make flake-check`, `make local-dry` (must be functionally identical to pre-reorg), spot-check HLC Pi5 + Pi4: `make dry-run HOST=hlc-501`, `make dry-run HOST=hlc-401`. All must pass.

**Checkpoint**: Module reorganization complete. Silicon and HLC unchanged. i3 split done. Polybar parameterized. Ready for Gibson.

---

## Phase 3: User Story 1 — Boot into NixOS on Gibson (Priority: P1) 🎯 MVP

**Goal**: Gibson boots NixOS with NVIDIA drivers, all 4 drives mounted, from a new flake entry. Uses single shared `home/eaglerock.nix` — no `eaglerock-gibson.nix`.

**Independent Test**: `nixos-rebuild dry-run --flake .#gibson` evaluates successfully; `nixos-rebuild dry-run --flake .#silicon` unchanged.

### Implementation

- [ ] T017 [P] [US1] Create `modules/hardware/gibson.nix` — AMD Ryzen 9 5950X microcode (`hardware.cpu.amd.updateMicrocode = true`), NVIDIA RTX 3080 config (`services.xserver.videoDrivers = ["nvidia"]`, `hardware.nvidia.open = true`, `hardware.nvidia.modesetting.enable = true`, `hardware.nvidia.powerManagement.enable = true`, `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable` with commented `.latest` alternative), graphics (`hardware.graphics.enable = true`, `hardware.graphics.enable32Bit = true`), SSD fstrim, no TLP/battery/lid/thinkfan/thermald (desktop); PipeWire 5.1 surround audio via `services.pipewire.wireplumber.extraConfig` (R-007): rule `"90-onboard-surround"` to pin `output:analog-surround-51+input:analog-stereo`, rule `"91-nvidia-sink-priority"` to lower NVIDIA HDMI sink to priority 500; NVIDIA fallback: include `nouveau` in `boot.initrd.availableKernelModules`. See research.md R-001, R-007
- [ ] T018 [P] [US1] Create `hosts/gibson/hardware-configuration.nix` — minimal placeholder: `boot.initrd.availableKernelModules` for NVMe + USB + NVIDIA, `boot.kernelModules = ["kvm-amd"]`, basic fileSystems for root + boot; will be replaced by `nixos-generate-config` during install
- [ ] T019 [US1] Create `hosts/gibson/configuration.nix` — imports `../../modules/nixos/workstation.nix`, `../../modules/nixos/workstation/grub.nix`, `../../modules/nixos/workstation/desktop-ui.nix`, `../../modules/nixos/workstation/gaming.nix`, `../../modules/hardware/gibson.nix`, `./hardware-configuration.nix`; sets `networking.hostName = "gibson"`, filesystem mounts (4 drives by-uuid with PLACEHOLDER values, nofail on non-root), `custom.hostProfile` values (`hasBattery = false`, `ethInterface = "TBD"`, `wlanInterface = "TBD"`, `defaultMonitor = "TBD"`); verify `networking.networkmanager.enable` is inherited from workstation module chain (FR-016) — confirm with `grep -r networkmanager modules/nixos/` post-reorg; NOTE: home-manager i3 variant import added in Phase 4 (T023)
- [ ] T020 [US1] Add `nixosConfigurations.gibson` to `flake.nix` — use `nixpkgs.lib.nixosSystem` with `system = "x86_64-linux"`, import `hosts/gibson/configuration.nix`, home-manager integration importing shared `home/eaglerock.nix` (same file as Silicon — no `eaglerock-gibson.nix`), add `nvidia-x11` and `nvidia-settings` to unfree allowlist with comment per Principle VI
- [ ] T021 [US1] Validate US1: run `make flake-check`, `make dry-run HOST=gibson`, `make local-dry` (Silicon must be unchanged)

**Checkpoint**: Gibson config evaluates. Silicon unchanged. MVP ready for physical install.

---

## Phase 4: User Story 2 — Triple-Monitor i3 Desktop (Priority: P1)

**Goal**: Gibson has a triple-monitor i3 desktop with workspace assignments, directional keybindings, and polybar on all 3 screens. Silicon behavior unchanged.

**Independent Test**: Both hosts evaluate; Silicon's polybar has battery module + wlan=wlp0s20f3; Gibson's polybar has no battery + correct interfaces.

### Implementation

- [ ] T022 [US2] Create `modules/home/workstation/i3/gibson.nix` — triple-monitor xrandr setup (output names TBD as placeholder strings: Left 1920x1080, Center 2560x1440, Right 1920x1080), `workspaceOutputAssign` mapping Left=ws3+9, Center=ws1+2+5+6+7+8, Right=ws4+10; directional workspace movement keybindings (`$mod+Ctrl+Left/Right`); same Gruvbox colors, terminal, modifier, fonts as common.nix (merged via module system); picom with `backend = "glx"`, `vsync = true`, `use-damage = false`, `unredir-if-possible = false` (NVIDIA-tuned per R-004); wallpaper reference to `assets/wallpaper-gibson.png`. Does NOT import `common.nix` — both are merged as separate NixOS modules via the module system. Monitor disconnect: no special handling needed — i3 natively reassigns workspaces to remaining outputs. See R-004, R-008
- [ ] T023 [US2] Wire Gibson i3 variant — add `../../modules/home/workstation/i3/gibson.nix` to `home-manager.users.eaglerock.imports` in `hosts/gibson/configuration.nix`; set final `custom.hostProfile` values (defaultMonitor TBD, ethInterface TBD, wlanInterface TBD — filled during physical install)
- [ ] T024 [US2] Validate US2: `make dry-run HOST=gibson` and `make local-dry`, verify both evaluate; `make flake-check`

**Checkpoint**: Both hosts have correct i3 variant. Polybar parameterized per host. Silicon regression-free.

---

## Phase 5: User Story 3 — GRUB Dual-Boot with Ubuntu (Priority: P2)

**Goal**: Gibson's GRUB menu shows NixOS (default) and Ubuntu as boot options via os-prober.

**Independent Test**: Gibson config includes os-prober; Silicon's GRUB unchanged.

### Implementation

- [ ] T025 [US3] Configure GRUB dual-boot in `hosts/gibson/configuration.nix` — `boot.loader.grub.useOSProber = true`, NixOS as default, timeout for menu display. Add commented-out `boot.loader.grub.extraEntries` with manual Ubuntu chainloader fallback (if os-prober fails to detect)
- [ ] T026 [US3] Validate US3: `make dry-run HOST=gibson`, `make local-dry` (Silicon unchanged)

**Checkpoint**: Dual-boot configured. Physical verification requires install.

---

## Phase 6: User Story 4 — Gaming Peripheral Support (Priority: P2)

**Goal**: Xbox One controller, Logitech joysticks, and G29 racing wheel work as non-root user.

**Independent Test**: Gaming module includes xpadneo, new-lg4ff, and udev rules in evaluation.

### Implementation

- [ ] T027 [US4] Enhance `modules/nixos/workstation/gaming.nix` — add `hardware.xpadneo.enable = true` (Xbox One via xpadneo DKMS), `hardware.new-lg4ff.enable = true` (G29 enhanced force feedback), udev rule `TAG+="uaccess"` for G29 (vendor `046d`, product `c24f`), testing tool packages (alphabetically sorted): `evtest`, `jstest-gtk`, `linuxConsoleTools`, `oversteer`. Keep existing Steam config. See research.md R-002
- [ ] T028 [US4] Validate US4: `make dry-run HOST=gibson` includes xpadneo/new-lg4ff; `make local-dry` also passes (inherits gaming.nix)

**Checkpoint**: Peripheral support configured. Physical verification requires hardware.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, constitution prep, final validation

- [ ] T029 [P] Update `CLAUDE.md` directory structure section to reflect post-reorg layout
- [ ] T030 [P] Update `specs/002-gibson-nixos-onboard/quickstart.md` with finalized install procedure and post-install verification
- [ ] T031 Draft constitution Principle VII amendment — update host capability table for Gibson as NixOS workstation. Save to `specs/002-gibson-nixos-onboard/constitution-amendment-draft.md`. NOT applied until physical install. Post-install follow-up: apply amendment and commit with `docs: amend constitution to vX.Y.Z` message.
- [ ] T032 Final validation: `make flake-check`, `make dry-run HOST=gibson`, `make local-dry`, HLC spot-check (`make dry-run HOST=hlc-501`, `make dry-run HOST=hlc-401`). Verify SC-007: confirm a future laptop host can be onboarded by creating only hardware module + host config + selecting i3/laptop.nix — no shared module changes needed. Verify Gruvbox theme consistency (FR-017): confirm `colors.nix` is imported by all workstation home modules. Note: `build-vm` not used for Gibson — NVIDIA proprietary drivers make QEMU testing infeasible per Principle IV "when feasible" clause.

**Checkpoint**: All configuration work complete. Ready for physical install on Gibson hardware.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (US5: Module Reorg) ← BLOCKS ALL
        └── Phase 3 (US1: Gibson Boot) ← MVP
            ├── Phase 4 (US2: Triple Monitor) ─┐
            ├── Phase 5 (US3: GRUB Dual-Boot) ─┤ can run parallel
            └── Phase 6 (US4: Gaming) ─────────┘
                └── Phase 7 (Polish) ← after all above
```

### User Story Dependencies

- **US5 (Module Reorg)**: Foundational — must complete first
- **US1 (Boot)**: Depends on US5 — MVP target
- **US2 (Triple Monitor)**: Depends on US1 (needs Gibson in flake + home-manager)
- **US3 (GRUB)**: Depends on US1 (needs Gibson host config)
- **US4 (Gaming)**: Depends on US1 (needs Gibson host config to validate)

### Within Phase 2 — Execution Order

```
T003 (dirs) → T004 (HLC extract) → T005–T009 [parallel: file moves]
→ T010a (picom reconcile ui.nix) → T010b (i3 split) → T011–T013 (import updates + cleanup)
→ T014 (hostProfile options) → T015 (polybar parameterize)
→ T016 (validate)
```

Key constraints:
- T004 before T008 (lib/hlc.nix must exist before RPi module paths in lib/ are updated)
- T009 before T010a (workstation/ dir must exist for picom reconciliation and i3/ subdirectory)
- T014 before T015 (hostProfile options must be defined before polybar reads them)

### Parallel Opportunities

- **Phase 2 file moves**: T005–T009 fully parallel (different source directories)
- **Phase 3 new files**: T017 + T018 parallel (separate new files)
- **Phases 4, 5, 6**: Can run parallel after Phase 3 (different files/concerns)
- **Phase 7**: T029 + T030 parallel

---

## Parallel Example: Phase 2 (File Moves)

```bash
# After T003 (dirs) and T004 (HLC), launch all file moves:
Task T005: "Move NixOS system modules hosts/ → nixos/"
Task T006: "Move cluster modules → nixos/server/"
Task T007: "Move misc NixOS modules (k8s, shell, users)"
Task T008: "Move RPi + SD modules → hardware/rpi/"
Task T009: "Move home workstation modules → home/workstation/"

# Then sequential: T010a (picom) → T010b (i3 split) → T011-T016
```

## Parallel Example: After Phase 3

```bash
# These three phases are independent — can run parallel:
Phase 4 (US2): Triple-monitor i3 (T022-T024)
Phase 5 (US3): GRUB dual-boot (T025-T026)
Phase 6 (US4): Gaming peripherals (T027-T028)

# NOTE: Phases 4+5 are order-independent but NOT file-concurrent —
# T023 and T025 both modify hosts/gibson/configuration.nix.
# Run in any order, not simultaneously.
```

---

## Implementation Strategy

### MVP First (Phase 2 + Phase 3)

1. Complete Phase 1: Baseline verification
2. Complete Phase 2: Module reorganization + i3 split + polybar parameterization (US5)
3. Complete Phase 3: Gibson boot config (US1)
4. **STOP and VALIDATE**: Both hosts evaluate, Silicon unchanged
5. Physical install feasible (Gibson boots with shared i3/common.nix — no variant until Phase 4)

### Incremental Delivery

1. Phase 2 → Reorganized architecture, parameterized polybar ✓
2. Phase 3 → Gibson boot config, MVP installable ✓
3. Phase 4 → Triple-monitor i3 + Gibson desktop ✓
4. Phase 5 + 6 → GRUB dual-boot + gaming (parallel) ✓
5. Phase 7 → Polish, docs, constitution prep ✓

### Physical Install Gate

Between Phase 3 and Phase 4, the operator performs the physical NixOS install:
1. Boot NixOS ISO from USB
2. Partition 2TB NVMe (512MB EFI + 32GB swap + rest ext4)
3. `nixos-generate-config` → replace `hosts/gibson/hardware-configuration.nix`
4. `xrandr` → discover output names for `i3/gibson.nix` (Phase 4)
5. `ip link` → discover interface names for `custom.hostProfile`
6. Replace PLACEHOLDER UUIDs in `hosts/gibson/configuration.nix`
7. `nixos-install --flake /path/to/nix-config#gibson`

---

## Notes

- [P] tasks = different files, no dependencies within the phase
- All import path updates (T011–T013) MUST run after all file moves (T005–T010b)
- Constitution amendment (T031) drafted but NOT applied until Gibson has NixOS
- Hardware-specific values (UUIDs, xrandr outputs, interfaces) are TBD until physical install
- Picom shared settings (`enable`, `fade`, `shadow`) in i3/common.nix; backend+vsync ONLY in variant files (laptop.nix: xrender; gibson.nix: glx) — removed from polybar.nix (T015) and ui.nix (T010a)
- i3 variant wired via `home-manager.users.eaglerock.imports` in each host's `configuration.nix` — NOT via string interpolation or extraSpecialArgs
- Polybar parameterized via `osConfig.custom.hostProfile.*` NixOS options — NOT via `extraSpecialArgs`
- Single shared `home/eaglerock.nix` for all workstations — NO per-host home entry files
- `dotfiles/` and `themes/` stay at `modules/home/` root (shared by base.nix)
- `layouts/` and `scripts/` move to `modules/home/workstation/` (i3/ui specific)
- PipeWire 5.1 surround profile name may need post-install tuning via `pactl list cards`
