# Tasks: Gibson NixOS Desktop Onboarding

**Input**: Design documents from `specs/002-gibson-nixos-onboard/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: No automated tests requested. Verification is via `make dry-run HOST=<host>` and operator visual spot checks (FR-028).

**Organization**: Tasks follow the 8-phase structure mandated by FR-031. Phase 2 is broken into 10 move groups per FR-028. Each move group ends with a verification checkpoint.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1=Boot, US2=Triple-monitor, US3=Dual-boot, US4=Gaming, US5=Architecture

---

## Phase 1: Gibson Scaffold

**Purpose**: Minimum viable Gibson host config. `make dry-run HOST=gibson` passes. No hardware-specific values yet — stubs until install.

- [ ] T001 Create `hosts/gibson/` directory
- [ ] T002 Create `hosts/gibson/hardware-configuration.nix` — stub with minimal fileSystems (root `/` on ext4, `/boot` EFI vfat) and placeholder UUIDs. Enough to evaluate, real values filled during install
- [ ] T003 Create `modules/hardware/gibson.nix` — NVIDIA driver config (`nvidiaPackages.stable`, commented `.latest` alternative), `hardware.nvidia.open = false`, `modesetting.enable`, `powerManagement.enable`, AMD microcode (`hardware.cpu.amd.updateMicrocode`), `hardware.graphics.enable` + `enable32Bit`, no TLP/thermald/lid. PipeWire 5.1 surround WirePlumber rules (R-007). Reference: FR-012, FR-018
- [ ] T004 Create `hosts/gibson/configuration.nix` — import `../../modules/hosts/workstation.nix`, `../../modules/hosts/grub.nix`, `../../modules/hosts/desktop-ui.nix`, `../../modules/hosts/gaming.nix`, `../../modules/hardware/gibson.nix`, `./hardware-configuration.nix`. Set hostname `gibson`, operator config, stateVersion. Reference: FR-013
- [ ] T005 Add `nixosConfigurations.gibson` to `flake.nix` — same pattern as silicon (`nixpkgs.lib.nixosSystem`). Add unfree allowlist entries: `nvidia-x11`, `nvidia-settings`. Import home-manager with `home-manager.users.eaglerock = import ./home/eaglerock.nix`
- [ ] T006 Run `make dry-run HOST=gibson` — must pass
- [ ] T007 Run `make dry-run HOST=silicon` — store path MUST be identical to pre-Phase-1 baseline (Principle IX). Record baseline store path for Phase 2 comparison

**Checkpoint**: Gibson evaluates. Silicon unchanged. Phase 2 can begin.

---

## Phase 2: Repo Restructure (US5 — Module Architecture)

**Purpose**: Reorganize module directories per FR-020–FR-024. Each move is an atomic commit with content byte-identical (FR-029). Gibson gets independent copies of UI modules (FR-014, FR-015). 10 move groups, each with Silicon verification + operator visual spot check (FR-028).

**CRITICAL**: Every task that moves/renames files MUST make one atomic commit per logical move. Commit message states what was moved and that content is unchanged. `make dry-run HOST=silicon` after EVERY commit.

### Move Group 1: NixOS Module Moves

- [ ] T008 [US5] Create `modules/nixos/` and `modules/nixos/workstation/` directories
- [ ] T009 [US5] Move `modules/hosts/common.nix` → `modules/nixos/common.nix` — content unchanged. Update import in `modules/hosts/workstation.nix` (`./common.nix` path unchanged since both files move together)
- [ ] T010 [US5] Move `modules/hosts/workstation.nix` → `modules/nixos/workstation.nix` — content unchanged
- [ ] T011 [US5] Move `modules/hosts/desktop-ui.nix` → `modules/nixos/workstation/desktop-ui.nix` — content unchanged
- [ ] T012 [US5] Move `modules/hosts/gaming.nix` → `modules/nixos/workstation/gaming.nix` — content unchanged
- [ ] T013 [US5] Move `modules/hosts/grub.nix` + `modules/hosts/grub/` → `modules/nixos/workstation/grub.nix` + `modules/nixos/workstation/grub/` — content unchanged
- [ ] T014 [US5] Update all import paths in `hosts/silicon/configuration.nix` — `../../modules/hosts/` → `../../modules/nixos/` (workstation.nix) and `../../modules/nixos/workstation/` (desktop-ui, gaming, grub)
- [ ] T015 [US5] Update all import paths in `hosts/gibson/configuration.nix` — same path updates as Silicon
- [ ] T016 [US5] Remove empty `modules/hosts/` directory
- [ ] T017 [US5] Run `make dry-run HOST=silicon` — identical store path. Run `make dry-run HOST=gibson` — passes
- [ ] T018 [US5] **CHECKPOINT 1**: Operator visual spot check on Silicon. **Check**: i3 starts, workspaces respond to Super+1-9, polybar visible on all bars, alacritty launches with correct colors. These are at risk because `workstation.nix` is the root NixOS module for Silicon's desktop

### Move Group 2: Cluster/Server Module Moves

- [ ] T019 [US5] Create `modules/nixos/server/` and `modules/nixos/server/hlc/` directories
- [ ] T020 [US5] Move `modules/cluster/common.nix` → `modules/nixos/server/common.nix` — content unchanged
- [ ] T021 [US5] Move `modules/cluster/motd.nix` → `modules/nixos/server/motd.nix` — content unchanged
- [ ] T022 [US5] Move `modules/cluster/prompt.nix` → `modules/nixos/server/prompt.nix` — content unchanged
- [ ] T023 [US5] Move `modules/cluster/hlc/` → `modules/nixos/server/hlc/` (all files: default.nix, hlc-recover-script.nix, hosts.nix, options.nix, provision.nix, raid-fallback.nix) — content unchanged
- [ ] T024 [US5] Update `flake.nix` — `clusterModule` paths: `./modules/cluster/hlc/default.nix` → `./modules/nixos/server/hlc/default.nix` and `./modules/cluster/hlc/provision.nix` → `./modules/nixos/server/hlc/provision.nix`
- [ ] T025 [US5] Update internal imports in moved server modules (relative paths like `../common.nix` — verify still correct after move)
- [ ] T026 [US5] Remove empty `modules/cluster/` directory
- [ ] T027 [US5] Run `make dry-run HOST=silicon` + `make dry-run HOST=hlc-501` — both unchanged
- [ ] T028 [US5] **CHECKPOINT 2**: Operator visual spot check on Silicon. **Check**: polybar network modules, dunst notifications (send test with `notify-send`). Cluster moves shouldn't affect Silicon but verify imports intact

### Move Group 3: Misc NixOS Module Moves

- [ ] T029 [US5] Move `modules/k8s/prereqs.nix` → `modules/nixos/k8s.nix` — content unchanged. Remove empty `modules/k8s/`
- [ ] T030 [US5] Move `modules/shell/` → `modules/nixos/shell/` (common.nix, utilities.nix) — content unchanged. Remove empty `modules/shell/`
- [ ] T031 [US5] Move `modules/users/operator.nix` → `modules/nixos/operator.nix` — content unchanged. Remove empty `modules/users/`
- [ ] T032 [US5] Update imports in `modules/nixos/common.nix` — shell/ and operator.nix paths. Update k8s import in `modules/nixos/server/common.nix`
- [ ] T033 [US5] Run `make dry-run HOST=silicon` — identical store path
- [ ] T034 [US5] **CHECKPOINT 3**: Operator visual spot check on Silicon. **Check**: open terminal, verify shell prompt renders correctly (Gruvbox colors, git branch display), `docker` command available, user groups correct (`groups` command)

### Move Group 4: Hardware Module Moves

- [ ] T035 [US5] Create `modules/hardware/rpi/` and `modules/hardware/rpi/sd/` directories
- [ ] T036 [US5] Move `modules/hardware/rpi4.nix` → `modules/hardware/rpi/rpi4.nix` — content unchanged
- [ ] T037 [US5] Move `modules/hardware/rpi5.nix` → `modules/hardware/rpi/rpi5.nix` — content unchanged
- [ ] T038 [US5] Move `modules/hardware/rpi-eeprom.nix` → `modules/hardware/rpi/rpi-eeprom.nix` — content unchanged
- [ ] T039 [US5] Move `modules/sd/` → `modules/hardware/rpi/sd/` (bootstrap.nix, recovery-utils.nix) — content unchanged. Remove empty `modules/sd/`
- [ ] T040 [US5] Update import paths in `flake.nix` — SD bootstrap path, piModule references for rpi4/rpi5
- [ ] T041 [US5] Update import paths in `modules/hardware/rpi/sd/recovery-utils.nix` — cluster import → server import
- [ ] T042 [US5] Update any HLC host configs importing rpi hardware modules
- [ ] T043 [US5] Run `make dry-run HOST=silicon` + `make dry-run HOST=hlc-501` — both unchanged
- [ ] T044 [US5] **CHECKPOINT 4**: Operator visual spot check on Silicon. **Check**: i3 launches, monitor resolution correct. Minimal visual risk from hardware module moves (x1-carbon.nix not moved). Quick confirmation only

### Move Group 5: Home-Manager Workstation Module Moves

- [ ] T045 [US5] Create `modules/home/workstation/` directory
- [ ] T046 [US5] Move `modules/home/dunst.nix` → `modules/home/workstation/dunst.nix` — content unchanged. Update `colors.nix` import path if relative (`./colors.nix` → `../colors.nix`)
- [ ] T047 [US5] Move `modules/home/ui.nix` → `modules/home/workstation/ui.nix` — content unchanged. Update internal import paths
- [ ] T048 [US5] Move `modules/home/dev.nix` → `modules/home/workstation/dev.nix` — content unchanged
- [ ] T049 [US5] Move `modules/home/vscode.nix` → `modules/home/workstation/vscode.nix` — content unchanged
- [ ] T050 [US5] Move `modules/home/layouts/` → `modules/home/workstation/layouts/` — content unchanged
- [ ] T051 [US5] Move `modules/home/scripts/` → `modules/home/workstation/scripts/` — content unchanged
- [ ] T052 [US5] Update all imports in `modules/home/workstation.nix` — `./dunst.nix` → `./workstation/dunst.nix`, `./ui.nix` → `./workstation/ui.nix`, etc.
- [ ] T053 [US5] Run `make dry-run HOST=silicon` — identical store path
- [ ] T054 [US5] **CHECKPOINT 5** (HIGH RISK): Operator visual spot check on Silicon. **Check**: alacritty transparency and colors, dunst notification popup (`notify-send "test" "checkpoint 5"`), i3 window borders and gaps and colors, VS Code launches correctly, picom compositing (window shadows visible, transparency works). These modules directly control Silicon's visual appearance

### Move Group 6: i3 Duplication for Gibson

- [ ] T055 [US5] Create `modules/home/workstation/i3/` directory
- [ ] T056 [US5] Move `modules/home/i3.nix` → `modules/home/workstation/i3/laptop.nix` — content unchanged (rename only)
- [ ] T057 [US5] Copy `modules/home/workstation/i3/laptop.nix` → `modules/home/workstation/i3/gibson.nix` — independent copy for Gibson. Content identical to laptop.nix at this point; Gibson-specific changes in Phase 4
- [ ] T058 [US5] Update import in `modules/home/workstation.nix` — `./i3.nix` → `./workstation/i3/laptop.nix`
- [ ] T059 [US5] Run `make dry-run HOST=silicon` — identical store path
- [ ] T060 [US5] **CHECKPOINT 6** (HIGHEST RISK): Operator visual spot check on Silicon. This is the exact change type that broke Silicon before. **Check**: ALL i3 keybindings (Super+1 through Super+0, Super+Enter for terminal, Super+d for dmenu/rofi), workspace switching between all workspaces, window movement (Super+Shift+arrow), floating toggle (Super+Shift+space), resize mode (Super+r), i3bar/polybar visible on all outputs, picom compositing (transparency, shadows), scratchpad (Super+minus to show, Super+Shift+minus to move to scratchpad), workspace 1 layout restoration (3 terminals)

### Move Group 7: Polybar Duplication for Gibson

- [ ] T061 [US5] Move `modules/home/polybar.nix` → `modules/home/workstation/polybar-laptop.nix` — content unchanged (rename only). Update `colors.nix` import path if needed
- [ ] T062 [US5] Copy `modules/home/workstation/polybar-laptop.nix` → `modules/home/workstation/polybar-gibson.nix` — independent copy. Content identical at this point; Gibson-specific changes in Phase 4
- [ ] T063 [US5] Update import in `modules/home/workstation.nix` — `./polybar.nix` → `./workstation/polybar-laptop.nix`
- [ ] T064 [US5] Run `make dry-run HOST=silicon` — identical store path
- [ ] T065 [US5] **CHECKPOINT 7**: Operator visual spot check on Silicon. **Check**: polybar visible on all bars, all modules rendering (battery percentage, WiFi SSID, CPU/memory usage, workspace indicators, date/time, volume icon), click actions work (volume, network), correct Gruvbox colors

### Move Group 8: Remaining Home Module Duplications

- [ ] T066 [US5] Audit remaining workstation modules for Gibson-specific differences. Candidates: picom (if separate from i3 variant files), any module where Gibson needs different config. Most modules (dunst, dev, vscode) are expected to be shared
- [ ] T067 [US5] For each module identified as needing Gibson-specific config: create independent copy in `modules/home/workstation/`. For shared modules: no action (imported via common workstation.nix path)
- [ ] T068 [US5] Run `make dry-run HOST=silicon` — identical store path
- [ ] T069 [US5] **CHECKPOINT 8**: Operator visual spot check on Silicon. **Check**: alacritty font and transparency, dunst notification style, GTK theme (open file dialog or settings). Low risk — most modules unchanged

### Move Group 9: Flake.nix + Host Profile Changes

- [ ] T070 [US5] Create `lib/hlc.nix` — extract HLC helper functions (`mkHlcNode`, `mkHlcProvision`, `mkHlcBootstrap`, `mkSdImages`, `pi4Hosts`, `pi5Hosts`) from `flake.nix`. Function receives inputs, returns helper set. Reference: R-009
- [ ] T071 [US5] Update `flake.nix` — import `lib/hlc.nix`, replace inline helpers with imported versions. Verify all nixosConfigurations still reference correctly
- [ ] T072 [US5] Add `custom.hostProfile` NixOS options to `modules/nixos/workstation.nix` — `hasBattery` (bool), `wlanInterface` (str), `ethInterface` (str), `defaultMonitor` (str). Reference: R-003
- [ ] T073 [US5] Set `custom.hostProfile` values in `hosts/silicon/configuration.nix` — `hasBattery = true`, `wlanInterface = "wlp0s20f3"`, `defaultMonitor = "eDP-1"`
- [ ] T074 [US5] Add `home-manager.users.eaglerock.imports` to Silicon's flake.nix config block — `[ ../../modules/home/workstation/i3/laptop.nix ]` (wires Silicon's i3 variant)
- [ ] T075 [US5] Add `home-manager.users.eaglerock.imports` to Gibson's flake.nix config block — `[ ../../modules/home/workstation/i3/gibson.nix ../../modules/home/workstation/polybar-gibson.nix ]`
- [ ] T076 [US5] Run `make dry-run HOST=silicon` — identical store path. Run `make dry-run HOST=gibson` — passes
- [ ] T077 [US5] **CHECKPOINT 9**: Operator visual spot check on Silicon. This group changes flake.nix and Silicon's configuration.nix directly. **Check**: full desktop — LightDM login, i3 session startup, all workspace keybindings, polybar all modules, alacritty, dunst, picom, lock screen (if configured)

### Move Group 10: Final Full Validation

- [ ] T078 [US5] Run `make dry-run HOST=silicon` — compare store path to Phase 1 baseline recorded in T007
- [ ] T079 [US5] Run `make dry-run HOST=gibson` — passes
- [ ] T080 [US5] Run `make dry-run HOST=hlc-501` — spot check cluster node (content-immutable)
- [ ] T081 [US5] **CHECKPOINT 10**: Complete Silicon desktop validation. Operator runs full daily workflow: terminal usage, browser launch (Firefox ws 3), VS Code (ws 2), workspace switching across all 10 workspaces, window movement between workspaces, multi-monitor if available, notifications, lock screen, volume control

**Checkpoint**: Phase 2 complete. All module paths reorganized. Silicon unchanged. Gibson has independent module copies. Ready for Gibson-specific work.

---

## Phase 3: Gibson Boot & Storage (US1 + US3)

**Goal**: Gibson boots NixOS with correct filesystem layout and GRUB dual-boot with Ubuntu.

**Independent Test**: Boot Gibson, verify all drives mounted, GRUB shows NixOS + Ubuntu.

**Operator prerequisite**: Manual NixOS install on Gibson (boot USB, partition 2TB NVMe, `nixos-install`). Discover UUIDs, GPU output names, network interfaces.

- [ ] T082 [US1] Update `hosts/gibson/hardware-configuration.nix` with real values from `nixos-generate-config` — actual disk UUIDs, detected kernel modules, hardware scan results
- [ ] T083 [US1] Configure filesystem mounts in `hosts/gibson/configuration.nix` — root (`/`) on 2TB NVMe ext4, `/boot` EFI vfat, swap (32GB, no resume device). Mount Ubuntu NVMe at `/mnt/ubuntu` with `nofail`, games NVMe (XFS) at `/srv` with `nofail`, HDD at `/mnt/hdd` with `nofail`. All `by-uuid`. Reference: FR-002, FR-003
- [ ] T084 [US3] Configure GRUB dual-boot in `hosts/gibson/configuration.nix` — `boot.loader.grub.enable`, `efiSupport`, `device = "nodev"`, `useOSProber = true`, NixOS default. `boot.loader.efi.canTouchEfiVariables = true`. Reference: FR-004, R-002
- [ ] T085 [US1] Configure suspend-to-RAM in `hosts/gibson/configuration.nix` — no hibernate, swap is runtime-only, NVIDIA power management handles suspend/resume. Reference: FR-025
- [ ] T086 [US1] Configure NetworkManager in `hosts/gibson/configuration.nix` — wired ethernet + WiFi. Reference: FR-016
- [ ] T087 [US1] Run `make dry-run HOST=silicon` — unchanged. Run `make dry-run HOST=gibson` — passes
- [ ] T088 [US1] Operator: run `nixos-install --flake .#gibson` on Gibson, reboot, verify boot, login to i3, check `lsblk`/`mount` for all 4 drives, verify `nvidia-smi` shows RTX 3080
- [ ] T089 [US3] Operator: reboot Gibson, verify GRUB menu shows NixOS + Ubuntu, boot into Ubuntu to confirm it's untouched, boot back to NixOS

**Checkpoint**: Gibson boots into NixOS i3. All drives mounted. GRUB dual-boot works. US1 core + US3 complete.

---

## Phase 4: Gibson i3 Desktop (US2)

**Goal**: Triple-monitor i3 with correct workspace assignments, directional movement, and polybar on all monitors.

**Independent Test**: Log into i3 on Gibson, verify 3 monitors, workspace navigation, polybar.

- [ ] T090 [US2] Update `modules/home/workstation/i3/gibson.nix` — triple-monitor xrandr setup using discovered output names (DP-0, DP-1, HDMI-0 etc.). Set resolutions: center 2560x1440, left 1920x1080, right 1920x1080. Reference: FR-005
- [ ] T091 [US2] Configure workspace-to-monitor assignment in `modules/home/workstation/i3/gibson.nix` — Left: ws 3 (Firefox) + ws 9 (spare), Right: ws 4 (Discord) + ws 10 (spare), Center: ws 1, 2, 5, 6, 7, 8. Reference: FR-005
- [ ] T092 [US2] Add directional workspace movement keybindings in `modules/home/workstation/i3/gibson.nix` — move workspace left/right between the three monitors. Reference: FR-006
- [ ] T093 [US2] Update picom config in `modules/home/workstation/i3/gibson.nix` — switch to `backend = "glx"`, `vsync = true`, `use-damage = false`, `unredir-if-possible = false`. Reference: R-004
- [ ] T094 [US2] Configure startup layout in `modules/home/workstation/i3/gibson.nix` — workspace 1 with 3 alacritty terminals + floating scratchpad. Same as Silicon. Reference: FR-019
- [ ] T095 [US2] Update `modules/home/workstation/polybar-gibson.nix` — remove battery module, set correct network interfaces (ethernet + WiFi), set default monitor to center monitor. Correct Gruvbox colors. Reference: FR-007
- [ ] T096 [US2] Run `make dry-run HOST=silicon` — unchanged. Apply on Gibson
- [ ] T097 [US2] Operator: verify all 3 monitors display content at correct resolutions, workspace switching via keybindings, directional workspace movement, polybar on all 3 monitors with correct modules, Gruvbox theme consistent

**Checkpoint**: US2 complete. Triple-monitor Gibson desktop fully functional.

---

## Phase 5: Gaming Peripherals (US4)

**Goal**: Xbox controller, Logitech joysticks, and G29 wheel work as non-root user.

**Independent Test**: Connect each peripheral, verify detection and functionality in Steam.

- [ ] T098 [US4] Add `hardware.xpadneo.enable = true` to `modules/nixos/workstation/gaming.nix` or Gibson-specific config. Reference: FR-008, R-002
- [ ] T099 [US4] Add `hardware.new-lg4ff.enable = true` to Gibson-specific config. Reference: FR-010, R-002
- [ ] T100 [US4] Add udev rules for gaming HID devices — `TAG+="uaccess"` for G29 (vendor 046d, product c24f), general gamepad access. Reference: FR-011
- [ ] T101 [US4] Run `make dry-run HOST=silicon` — verify store path. If gaming.nix changes affect Silicon derivation, refactor gaming peripheral enables to Gibson-only config. Store path MUST be identical
- [ ] T102 [US4] Operator: connect Xbox controller (USB), verify `evtest` shows input. Connect Logitech joystick, verify `jstest`. Connect G29, verify `fftest` for force feedback. Test in Steam game

**Checkpoint**: US4 complete. All gaming peripherals functional.

---

## Phase 6: Audio & System (US1 remaining)

**Goal**: PipeWire 5.1 surround audio output and microphone input via onboard audio.

**Independent Test**: Play audio through 5.1 surround speakers, verify all 6 channels.

- [ ] T103 [US1] Verify PipeWire 5.1 surround config in `modules/hardware/gibson.nix` (created in T003) — WirePlumber rule `90-onboard-surround` matches onboard HD-Audio card, sets `output:analog-surround-51+input:analog-stereo` profile. Reference: FR-018, R-007
- [ ] T104 [US1] Verify NVIDIA HDMI audio deprioritization rule in `modules/hardware/gibson.nix` — rule `91-nvidia-sink-priority` lowers HDMI sink priority so onboard analog is default. Reference: R-007
- [ ] T105 [US1] Run `make dry-run HOST=silicon` — unchanged
- [ ] T106 [US1] Operator: apply on Gibson. Run `pactl list cards` to verify surround profile active. Play test audio through all 6 channels (`speaker-test -c 6`). Test microphone input

**Checkpoint**: US1 fully complete. Gibson boots, mounts all drives, has working audio, suspends/resumes, network works.

---

## Phase 7: Code Deduplication (US5 — parallel with Phases 4-6)

**Goal**: Extract shared logic from duplicated modules into common.nix + host-specific deltas. Runs in parallel with Phases 4-6 (FR-031).

**Independent Test**: Both hosts build identically to pre-dedup state. Silicon visual spot check after each module dedup.

### i3 Deduplication

- [ ] T107 [US5] Diff `modules/home/workstation/i3/laptop.nix` vs `i3/gibson.nix` — identify shared lines (~250 lines: keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout)
- [ ] T108 [US5] Create `modules/home/workstation/i3/common.nix` — extract shared i3 config. Update `modules/home/workstation.nix` to import `./workstation/i3/common.nix` instead of (or in addition to) `i3/laptop.nix`
- [ ] T109 [US5] Reduce `modules/home/workstation/i3/laptop.nix` to Silicon-specific delta only — xrandr scaling, brightness keys, xrender picom. Merges with common.nix via NixOS module system. Reference: FR-014b
- [ ] T110 [US5] Reduce `modules/home/workstation/i3/gibson.nix` to Gibson-specific delta only — triple-monitor xrandr, glx picom, directional workspace movement. Reference: FR-014b
- [ ] T111 [US5] Run `make dry-run HOST=silicon` — identical store path. Run `make dry-run HOST=gibson` — passes
- [ ] T112 [US5] Operator visual spot check on Silicon after i3 dedup — full i3 keybinding check, workspace switching, picom compositing

### Polybar Deduplication

- [ ] T113 [US5] Create parameterized `modules/home/workstation/polybar.nix` — read `osConfig.custom.hostProfile` for battery, network interfaces, default monitor. Conditionally include battery module, use correct interface names. Reference: FR-015b, R-003
- [ ] T114 [US5] Replace `polybar-laptop.nix` and `polybar-gibson.nix` with single parameterized `polybar.nix`. Update import in `modules/home/workstation.nix`. Remove per-host polybar imports from flake.nix host configs
- [ ] T115 [US5] Run `make dry-run HOST=silicon` — identical store path. Run `make dry-run HOST=gibson` — passes
- [ ] T116 [US5] Operator visual spot check on Silicon — polybar all modules rendering, battery present, WiFi interface correct

### Remaining Module Dedup

- [ ] T117 [US5] For each remaining duplicated module (picom, dunst, others from T067): diff variants, evaluate whether dedup is worthwhile. **Ask operator** before keeping any module as independent copies — operator's judgment call (FR-030)
- [ ] T118 [US5] Deduplicate approved modules. For each: extract common config, reduce variants to deltas, verify both hosts unchanged
- [ ] T119 [US5] Run `make dry-run HOST=silicon` — identical store path. Final operator visual spot check

**Checkpoint**: US5 complete. Architecture supports multiple hosts with shared common modules and host-specific deltas.

---

## Phase 8: Polish & Final Validation

**Purpose**: Final verification, documentation, cleanup.

- [ ] T120 Run `make dry-run HOST=silicon` — verify store path matches original pre-Phase-1 baseline
- [ ] T121 Run `make dry-run HOST=gibson` — passes cleanly
- [ ] T122 Run `make dry-run HOST=hlc-501` — cluster node unchanged
- [ ] T123 Update `CLAUDE.md` — directory structure section reflects new module layout, build commands include Gibson, Gibson host listed in project overview
- [ ] T124 Verify `specs/002-gibson-nixos-onboard/quickstart.md` is accurate for final state
- [ ] T125 [P] Constitution Principle VII table update — Gibson now has NixOS (PATCH bump). Update `gibson` row: `nixos-rebuild` now available
- [ ] T126 Operator: full daily workflow test on both Silicon and Gibson. Verify SC-001 through SC-007

**Checkpoint**: All user stories verified. Ready for merge.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Scaffold) ──→ Phase 2 (Restructure) ──┬──→ Phase 3 (Boot/Storage) ──→ Phase 8 (Polish)
                                                 ├──→ Phase 4 (i3 Desktop)   ──→ Phase 8
                                                 ├──→ Phase 5 (Gaming)       ──→ Phase 8
                                                 ├──→ Phase 6 (Audio)        ──→ Phase 8
                                                 └──→ Phase 7 (Dedup)        ──→ Phase 8
```

- **Phase 1**: No dependencies — start immediately
- **Phase 2**: Depends on Phase 1 — BLOCKS all subsequent phases
- **Phases 3-6**: All depend on Phase 2. Can run in parallel (different files)
- **Phase 7**: Depends on Phase 2. MAY run in parallel with Phases 4-6
- **Phase 8**: Depends on all previous phases

### User Story Independence

- **US1** (Boot): Phases 1 + 3 + 6 — can be tested after Phase 6
- **US2** (Triple-monitor): Phase 4 — testable after Phase 4
- **US3** (Dual-boot): Phase 3 — testable after Phase 3
- **US4** (Gaming): Phase 5 — testable after Phase 5
- **US5** (Architecture): Phases 2 + 7 — testable after Phase 7

### Parallel Opportunities

Within Phase 2 move groups: sequential (each depends on prior group's import updates).

After Phase 2, these can run in parallel:
- Phase 3 (T082-T089) and Phase 4 (T090-T097) — different files
- Phase 5 (T098-T102) — different files from Phase 4
- Phase 6 (T103-T106) — different files
- Phase 7 (T107-T119) — depends on Phase 2 only, runs alongside 4-6

---

## Implementation Strategy

### MVP First (US1 — Boot into NixOS)

1. Complete Phase 1: Gibson scaffold
2. Complete Phase 2: Repo restructure (Silicon stays stable)
3. Complete Phase 3: Gibson boots with all drives + GRUB
4. **STOP and VALIDATE**: Boot Gibson, verify base system works
5. Gibson is usable (basic i3 with Silicon's config)

### Incremental Delivery

1. Phase 1 + 2 → Architecture ready
2. Phase 3 → Gibson boots (MVP — US1 core + US3)
3. Phase 4 → Triple-monitor desktop (US2)
4. Phase 5 → Gaming peripherals (US4)
5. Phase 6 → Audio + system polish (US1 complete)
6. Phase 7 → DRY architecture (US5 complete)
7. Phase 8 → Ship it
