# Tasks: Gibson NixOS Desktop Onboarding

**Input**: Design documents from `/specs/002-gibson-nixos-onboard/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Implementation order follows plan.md phases: refactor first (US5), then hardware (US1), desktop (US2), dual-boot (US3), peripherals (US4).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify starting state and ensure Silicon builds cleanly before any changes

- [ ] T001 Run `make flake-check` and `make local-dry` to capture Silicon baseline

---

## Phase 2: Foundational — Module Architecture Refactoring (US5 prerequisites)

**Purpose**: Refactor existing modules for multi-host support. Silicon MUST remain identical after this phase. These changes are blocking prerequisites for all Gibson-specific work.

**⚠️ CRITICAL**: No Gibson-specific work can begin until this phase is complete. Each task must be verified with `make local-dry`.

### 2a. i3 Rename

- [ ] T002 [US5] Rename `modules/home/i3.nix` to `modules/home/i3-laptop.nix`
- [ ] T003 [US5] Update import in `modules/home/workstation.nix` from `./i3.nix` to `./i3-laptop.nix`
- [ ] T004 [US5] Verify Silicon: `make local-dry` — identical output

### 2b. Polybar Parameterization

- [ ] T005 [US5] Add `hostProfile` to `home-manager.extraSpecialArgs` in `flake.nix` for Silicon: `{ hasBattery = true; wlanInterface = "wlp0s20f3"; ethInterface = ""; defaultMonitor = "eDP-1"; }`
- [ ] T006 [US5] Parameterize `modules/home/polybar.nix` — add `hostProfile` to function args, replace hardcoded `wlp0s20f3` with `hostProfile.wlanInterface`, replace `eDP-1` fallback with `hostProfile.defaultMonitor`, wrap battery module in `lib.optionalAttrs hostProfile.hasBattery`, add conditional ethernet module via `lib.optionalAttrs (hostProfile.ethInterface != "")`
- [ ] T007 [US5] Verify Silicon: `make local-dry` — identical output

### 2c. Gaming Peripheral Support

- [ ] T008 [US5] Add peripheral drivers to `modules/hosts/gaming.nix` — `hardware.xpadneo.enable = true`, `hardware.new-lg4ff.enable = true`, udev rule for G29 (vendor 046d, product c24f) with `TAG+="uaccess"`, testing/tuning tools (`evtest`, `linuxConsoleTools`, `jstest-gtk`, `oversteer`)
- [ ] T009 [US5] Verify Silicon: `make local-dry` — builds without regressions

**Checkpoint**: Module architecture supports multiple hosts. Silicon behavior unchanged. Foundation ready for Gibson-specific work.

---

## Phase 3: User Story 1 — Boot into NixOS on Gibson (Priority: P1) 🎯 MVP

**Goal**: Gibson boots NixOS with AMD CPU, NVIDIA GPU drivers, and all drives mounted. Silicon unaffected.

**Independent Test**: Boot Gibson from 2TB NVMe, log in via LightDM, confirm i3 session with working display and all drives mounted. Run `nvidia-smi` to verify RTX 3080 detected.

### Implementation for User Story 1

- [ ] T010 [P] [US1] Create `modules/hardware/gibson.nix` — AMD CPU microcode + `kvm-amd`, NVIDIA GPU config (`services.xserver.videoDrivers = ["nvidia"]`, `hardware.nvidia.open = true`, modesetting, power management), `hardware.graphics.enable` + `enable32Bit`, Vulkan packages (`vulkan-loader`, `vulkan-tools`), desktop monitoring (`lm_sensors`, `nvtopPackages.nvidia`), no laptop power management. NOTE: if NVIDIA driver fails to load, NixOS falls back to console TTY by default — verify post-install that a TTY login is reachable even without GPU driver
- [ ] T011 [P] [US1] Create `hosts/gibson/hardware-configuration.nix` — placeholder with known drive layout (2TB NVMe root + EFI + swap, Ubuntu NVMe at `/mnt/ubuntu`, XFS games at `/srv`, HDD at `/mnt/hdd`), all mounts `by-uuid` with `FIXME-UUID-ROOT`, `FIXME-UUID-EFI`, `FIXME-UUID-SWAP`, `FIXME-UUID-UBUNTU`, `FIXME-UUID-GAMES`, `FIXME-UUID-HDD` placeholders, `nofail` on non-root, AMD microcode, kernel modules (`nvme`, `xhci_pci`, `ahci`, `usbhid`, `sd_mod` initrd; `kvm-amd` kernel)
- [ ] T012 [P] [US1] Create `hosts/gibson/configuration.nix` — hostname `gibson`, operator eaglerock (same groups as Silicon), imports (workstation.nix, grub.nix, desktop-ui.nix, gaming.nix, gibson.nix, hardware-configuration.nix), unfree allowlist (`nvidia-x11`, `nvidia-settings` added to existing list), state version 25.11. NOTE: os-prober NOT included here — deferred to T019 (US3)
- [ ] T013 [US1] Add `nixosConfigurations.gibson` to `flake.nix` — new host entry, `home-manager.extraSpecialArgs` with Gibson `hostProfile` (`hasBattery = false`, `wlanInterface = "FIXME-WLAN"`, `ethInterface = "FIXME-ETH"`, `defaultMonitor = "FIXME-MONITOR-CENTER"`), `home-manager.users.eaglerock = import ./home/eaglerock-gibson.nix`
- [ ] T014 [US1] Verify: `make flake-check`, `make dry-run HOST=gibson` evaluates (FIXME placeholders expected), `make local-dry` Silicon unaffected

**Checkpoint**: Gibson config evaluates. Silicon unchanged. MVP foundation complete.

---

## Phase 4: User Story 2 — Triple-Monitor i3 Desktop (Priority: P1)

**Goal**: Three monitors display content with correct workspace assignments, directional keybindings, and host-adapted polybar on all screens.

**Independent Test**: Log into i3 on Gibson, verify all 3 monitors display content, switch workspaces across screens, confirm polybar visible on each monitor with no battery module.

### Implementation for User Story 2

- [ ] T015 [P] [US2] Create `modules/home/i3-gibson.nix` — copy `i3-laptop.nix` as base, remove laptop xrandr (scaling/DPI), add triple-monitor xrandr with placeholders (`FIXME-OUTPUT-LEFT`, `FIXME-OUTPUT-CENTER`, `FIXME-OUTPUT-RIGHT`), workspace-to-output assignments (Left=ws 3,9; Right=ws 4,10; Center=ws 1,2,5,6,7,8), directional keybindings (`$mod+Shift+Left/Right` move workspace to adjacent output), keep `$mod+x` move-to-next-output, same app class assignments as Silicon, same startup (ws 1 layout, 3 terminals, scratchpad, polybar restart, picom, wallpaper), Gruvbox colors from `colors.nix`
- [ ] T016 [P] [US2] Create `modules/home/workstation-gibson.nix` — copy `workstation.nix`, change i3 import to `./i3-gibson.nix`, all other imports identical (base.nix, ui.nix, polybar.nix, dunst.nix, dev.nix, vscode.nix)
- [ ] T017 [US2] Create `home/eaglerock-gibson.nix` — import `../modules/home/workstation-gibson.nix`, same structure as `home/eaglerock.nix`
- [ ] T018 [US2] Verify: `make dry-run HOST=gibson` evaluates with i3-gibson and polybar without battery, `make local-dry` Silicon unaffected

**Checkpoint**: Gibson desktop config complete with triple-monitor i3 and parameterized polybar.

---

## Phase 5: User Story 3 — GRUB Dual-Boot with Ubuntu (Priority: P2)

**Goal**: GRUB boot menu shows NixOS as default and Ubuntu as selectable option via os-prober.

**Independent Test**: Reboot Gibson, confirm GRUB menu shows both NixOS and Ubuntu, boot into each successfully.

### Implementation for User Story 3

- [ ] T019 [US3] Enable `boot.loader.grub.useOSProber = true` in `hosts/gibson/configuration.nix` (Ubuntu NVMe must be visible at build time). NOTE: if os-prober fails to detect Ubuntu post-install, add a manual GRUB `boot.loader.grub.extraEntries` menuentry pointing to Ubuntu's EFI partition as fallback
- [ ] T020 [US3] Verify: `make dry-run HOST=gibson` evaluates with os-prober enabled

- [ ] T021 [US3] Post-install: Reboot Gibson, confirm GRUB menu shows NixOS (default) and Ubuntu, boot into Ubuntu and back into NixOS

**Checkpoint**: Dual-boot GRUB configured and verified.

---

## Phase 6: User Story 4 — Gaming Peripheral Support (Priority: P2)

**Goal**: Xbox One controllers, Logitech joysticks, and G29 racing wheel work as non-root user.

**Independent Test**: Connect each peripheral, verify with `evtest`/`jstest`/`fftest`, confirm functionality in a Steam game.

*Note: The driver and udev configuration was already added in Phase 2 (T008) as part of the foundational refactoring, since these changes are harmless on Silicon. This phase exists only for install-time hardware verification.*

- [ ] T022 [US4] Post-install: Connect Xbox One controller via USB, verify with `evtest` as non-root user
- [ ] T023 [US4] Post-install: Connect Logitech joystick, verify axes and buttons with `jstest`
- [ ] T024 [US4] Post-install: Connect G29 wheel, verify force feedback with `fftest`

**Checkpoint**: All gaming peripherals functional under non-root user.

---

## Phase 7: User Story 5 — Module Architecture Supports Multiple Hosts (Priority: P3)

**Goal**: Flake cleanly supports both Silicon and Gibson with shared modules and host-specific variants. Architecture ready for future Carbon laptop.

**Independent Test**: Both `make local-dry` (Silicon) and `make dry-run HOST=gibson` succeed with correct host-specific module selection.

*Note: The implementation work for US5 was front-loaded into Phase 2 (foundational refactoring) and completed across Phases 3–4. This phase is verification only.*

- [ ] T025 [US5] Verify architecture: confirm Silicon imports `i3-laptop.nix` and Gibson imports `i3-gibson.nix`
- [ ] T026 [US5] Verify polybar parameterization: Gibson has no battery module and correct network interfaces; Silicon is identical to pre-refactor behavior
- [ ] T027 [US5] Verify extensibility: review module structure confirms a third host (Carbon) can be onboarded by creating hardware module, host config, i3 variant selection, and hostProfile — no shared module changes needed

**Checkpoint**: Multi-host architecture validated and future-proofed.

---

## Phase 8: Polish & Pre-Install Verification

**Purpose**: Final pre-install verification and install preparation

- [ ] T028 [P] Run `make flake-check` — all configs evaluate cleanly
- [ ] T029 [P] Run `make local-dry` — Silicon zero regression from baseline (T001)
- [ ] T030 [P] Run `make dry-run HOST=gibson` — evaluates (FIXME placeholders expected)
- [ ] T031 Run `grep -r FIXME` across gibson config files — confirm all placeholder sites are documented and discoverable
- [ ] T032 Run quickstart.md validation — confirm install procedure matches generated config

---

## Phase 9: Post-Install (on Gibson hardware)

**Purpose**: Replace placeholders with real values, verify hardware-specific functionality. These tasks execute AFTER `nixos-install --flake .#gibson` and first boot.

### 9a. Hardware Discovery & Placeholder Replacement

- [ ] T033 Replace placeholder UUIDs in `hosts/gibson/hardware-configuration.nix` with real values from `nixos-generate-config --root /mnt` output (replace all `FIXME-UUID-*` strings)
- [ ] T034 [P] Update `hostProfile` in `flake.nix` with real interface/monitor names from `ip link` and `xrandr` output (replace `FIXME-WLAN`, `FIXME-ETH`, `FIXME-MONITOR-CENTER`)
- [ ] T035 [P] Update `modules/home/i3-gibson.nix` xrandr and workspace output assignments with real GPU output names from `xrandr` (replace `FIXME-OUTPUT-LEFT`, `FIXME-OUTPUT-CENTER`, `FIXME-OUTPUT-RIGHT`)
- [ ] T036 Rebuild and apply: `make local-switch` on Gibson with real values

### 9b. Post-Install Verification

- [ ] T037 [P] Verify 5.1 surround audio output and microphone input via `pactl list sinks` / `pactl list sources` — if multi-channel not auto-detected, configure PipeWire ALSA profile for motherboard codec
- [ ] T038 [P] Verify NetworkManager manages both ethernet and WiFi: `nmcli device status` shows both interfaces
- [ ] T039 Update constitution host capability table (Principle VII) — Gibson is now NixOS; update table to show `nixos-rebuild` available. Execute only after Gibson is confirmed running NixOS.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — captures baseline
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all Gibson-specific work
- **US1 (Phase 3)**: Depends on Phase 2 — foundational MVP
- **US2 (Phase 4)**: Depends on Phase 2 + partially on T013 (flake.nix gibson entry) — can overlap with late Phase 3
- **US3 (Phase 5)**: Depends on T012 (gibson configuration.nix) — can be done in parallel with Phase 4
- **US4 (Phase 6)**: Install-time verification only — depends on T008 (foundational) + physical Gibson install
- **US5 (Phase 7)**: Verification only — depends on Phases 2–4 completion
- **Polish (Phase 8)**: Depends on all implementation phases (2–7) complete
- **Post-Install (Phase 9)**: Depends on physical `nixos-install` on Gibson hardware

### User Story Dependencies

- **US5 (architecture)**: Implemented first (Phase 2) despite P3 priority — enables all other stories
- **US1 (boot/hardware)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (desktop/i3)**: Can start after Phase 2 — shares flake.nix edit with US1 (T013)
- **US3 (dual-boot)**: Can start after US1 T012 creates gibson configuration.nix
- **US4 (peripherals)**: Driver config in Phase 2; verification requires physical install

### Within Each Phase

- Tasks marked [P] can run in parallel (different files)
- Verification tasks (T004, T007, T009, T014, T018, T020) must run after their preceding implementation tasks
- `flake.nix` edits (T005, T013) must be sequenced — T005 first, T013 after

### Parallel Opportunities

```
Phase 2:  T002 ──→ T003 ──→ T004
          T005 ──→ T006 ──→ T007  (after T004)
          T008 ──→ T009            (after T007)

Phase 3:  T010 ─┐
          T011 ─┼──→ T013 ──→ T014
          T012 ─┘

Phase 4:  T015 ─┐
          T016 ─┼──→ T017 ──→ T018
                ┘

Phase 5:  T019 ──→ T020  (can overlap with Phase 4)

Phase 9:  T033 ──→ T034 ─┐
                   T035 ─┼──→ T036 ──→ T037 ─┐
                         ┘              T038 ─┼──→ T039
                                              ┘
```

---

## Implementation Strategy

### MVP First (US5 + US1)

1. Complete Phase 1: Baseline capture
2. Complete Phase 2: Foundational refactoring (Silicon unchanged)
3. Complete Phase 3: Gibson boots NixOS with GPU + all drives
4. **STOP and VALIDATE**: `make flake-check`, dry-run both hosts
5. Ready for physical install with minimal viable config

### Incremental Delivery

1. Phase 1–2 → Foundation ready, Silicon unchanged
2. Phase 3 (US1) → Gibson boots NixOS → **MVP install-ready**
3. Phase 4 (US2) → Triple-monitor desktop → Full daily-driver
4. Phase 5 (US3) → Dual-boot GRUB → Ubuntu preserved
5. Phase 6 (US4) → Gaming peripheral drivers ready (verification post-install)
6. Phase 7–8 → Architecture validated, pre-install verification complete
7. **INSTALL** → `nixos-install --flake .#gibson` on physical hardware
8. Phase 9 → Replace placeholders, verify hardware, update constitution

### Suggested MVP Scope

Phases 1–3 (T001–T014): Gibson boots NixOS with NVIDIA drivers and all drives mounted. This is sufficient for `nixos-install` and represents the minimum useful configuration.

### Post-Install Placeholder Discovery

All placeholder values use `FIXME-` prefix for easy discovery:
```bash
grep -r FIXME hosts/gibson/ modules/home/i3-gibson.nix flake.nix
```
