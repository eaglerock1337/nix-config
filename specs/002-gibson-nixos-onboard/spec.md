# Feature Specification: Gibson NixOS Desktop Onboarding

**Feature Branch**: `002-gibson-nixos-onboard`  
**Created**: 2026-05-18  
**Status**: Draft  
**Input**: User description: "Onboard Gibson (Ryzen 9 5950X / RTX 3080 / 64GB RAM desktop) onto NixOS, reusing Silicon's curated i3 environment with adaptations for NVIDIA GPU, triple-monitor layout, multi-disk setup preserving Ubuntu, and gaming peripheral support."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Boot into NixOS on Gibson (Priority: P1)

The operator installs NixOS onto the new 2TB NVMe drive on Gibson and boots into a functional desktop environment. The system uses the Ryzen 9 5950X CPU with AMD microcode, loads proprietary NVIDIA drivers for the RTX 3080, and presents the i3 window manager with the Gruvbox Dark theme. All four drives are mounted at their designated locations, with only the 2TB NVMe having been formatted.

**Why this priority**: Nothing else works until the base system boots. This is the foundational slice — a working NixOS desktop on Gibson hardware.

**Independent Test**: Boot Gibson from the 2TB NVMe, log in via LightDM, and confirm an i3 session with working display output and all drives mounted.

**Acceptance Scenarios**:

1. **Given** a freshly partitioned 2TB NVMe (EFI + swap + root), **When** NixOS is built and installed with `nixos-rebuild switch --flake .#gibson`, **Then** the system boots to LightDM and the operator can log into an i3 session
2. **Given** the system is booted, **When** the operator runs `lsblk` and `mount`, **Then** the 2TB NVMe is mounted as `/`, the Ubuntu NVMe is mounted at `/mnt/ubuntu`, the games NVMe is mounted at `/srv`, and the HDD is mounted at `/mnt/hdd`
3. **Given** the system is booted, **When** the operator checks GPU status, **Then** NVIDIA proprietary drivers are loaded and `nvidia-smi` shows the RTX 3080
4. **Given** the system is booted, **When** the operator runs `nixos-rebuild dry-run --flake .#silicon` on the repo, **Then** the Silicon configuration is unaffected and still builds successfully

---

### User Story 2 - Triple-Monitor i3 Desktop (Priority: P1)

The operator uses Gibson's three monitors (27" 1440p center, 24" 1080p left, 24" 1080p right) with i3 workspaces distributed across all three screens. Keybindings allow moving windows and workspaces directionally between the three outputs. Polybar appears on all three monitors with host-appropriate modules (no battery, correct network interfaces).

**Why this priority**: The multi-monitor desktop is the primary daily interface. Without it, the system is functional but not usable for real work.

**Independent Test**: Log into i3, verify all three monitors display content, switch workspaces across screens using keybindings, confirm polybar is visible on each monitor.

**Acceptance Scenarios**:

1. **Given** all three monitors are connected, **When** the operator logs into i3, **Then** each monitor displays its assigned workspaces and polybar bar
2. **Given** a window is focused on the center monitor, **When** the operator uses the move-workspace-to-left or move-workspace-to-right keybinding, **Then** the workspace moves to the correct adjacent monitor
3. **Given** the operator is on any monitor, **When** they use workspace switch keybindings, **Then** focus moves to the correct workspace on the correct monitor
4. **Given** polybar is running on Gibson, **When** the operator inspects the bar, **Then** there is no battery module, and network status shows both ethernet and WiFi interfaces

---

### User Story 3 - GRUB Dual-Boot with Ubuntu (Priority: P2)

The operator can choose between NixOS and Ubuntu at boot time. GRUB is installed on the 2TB NVMe's EFI partition and detects the existing Ubuntu installation on the other NVMe via os-prober. NixOS is the default boot option.

**Why this priority**: The operator needs to preserve access to the existing Ubuntu install during the transition period for games already configured there.

**Independent Test**: Reboot Gibson, confirm GRUB menu shows both NixOS and Ubuntu, boot into each one successfully.

**Acceptance Scenarios**:

1. **Given** Gibson is powered on, **When** GRUB loads, **Then** NixOS is the default entry and Ubuntu appears as a selectable option
2. **Given** GRUB is displayed, **When** the operator selects Ubuntu, **Then** Ubuntu boots normally with its existing configuration intact
3. **Given** GRUB is displayed, **When** the timeout expires without input, **Then** NixOS boots automatically

---

### User Story 4 - Gaming Peripheral Support (Priority: P2)

The operator's gaming peripherals work under NixOS: Xbox One controllers connect via Bluetooth using the xpadneo driver, Logitech joysticks are recognized as input devices, and the Logitech G29 racing wheel provides force feedback in games via Steam/Proton.

**Why this priority**: Gaming is a primary use case for Gibson. Peripherals that don't work make the gaming desktop incomplete.

**Independent Test**: Connect each peripheral, verify it appears as an input device, and confirm functionality in a Steam game.

**Acceptance Scenarios**:

1. **Given** an Xbox One controller is connected via USB (or paired via Bluetooth), **When** the operator launches a game in Steam, **Then** the controller is recognized and provides input with vibration feedback
2. **Given** a Logitech joystick is plugged in via USB, **When** the operator runs a joystick testing tool or launches a game, **Then** all axes and buttons are detected and responsive
3. **Given** the Logitech G29 racing wheel is plugged in via USB, **When** the operator launches a racing game via Steam/Proton, **Then** steering, pedals, and force feedback function correctly
4. **Given** any gaming peripheral is connected, **When** the operator is a non-root user, **Then** the device is accessible without elevated privileges (via udev rules)

---

### User Story 5 - Module Architecture Supports Multiple Hosts (Priority: P3)

The NixOS configuration cleanly supports both Silicon (laptop) and Gibson (desktop) from the same flake, with a reorganized module directory structure. The work proceeds in two stages: **Phase 2 (Refactor)** moves/renames files and creates independent copies of host-specific modules for Gibson — Silicon's evaluated config MUST NOT change. **Phase 7 (Deduplication)** extracts shared logic into common modules (e.g., `i3/common.nix`) and reduces host variants to deltas. This two-stage approach ensures Silicon is never broken by architectural changes.

During Phase 2, modules are split into `modules/nixos/` (NixOS system modules) and `modules/home/` (home-manager modules), each with `workstation/` and `server/` subdirectories. Gibson gets independent copies of i3, polybar, and other UI modules. The `modules/cluster/` directory is absorbed into `modules/nixos/server/`. RPi and cluster configs are treated as immutable — content-unchanged moves only.

During Phase 7 (which MAY run in parallel with Phases 4–6), duplicated modules are deduplicated into `common.nix` + host-specific variants. The operator decides case-by-case whether a specific dedup is worth the complexity.

**Why this priority**: Good architecture prevents configuration drift and makes future host onboarding cheaper. The two-stage approach was adopted after a failed attempt where in-place refactoring broke Silicon's desktop (alacritty translucency, i3bar, workspace shortcuts).

**Independent Test**: Both `make dry-run HOST=silicon` and `make dry-run HOST=gibson` succeed at every Phase 2 checkpoint. Silicon's store path is unchanged after each move group. After Phase 7, both hosts build and the architecture supports adding a third host without modifying shared modules.

**Acceptance Scenarios**:

1. **Given** Phase 2 is in progress, **When** any file move or copy is committed, **Then** `make dry-run HOST=silicon` produces an identical derivation to before the commit
2. **Given** Phase 2 is complete, **When** Gibson's config is evaluated, **Then** Gibson imports its own independent `i3/gibson.nix` and polybar config, and Silicon imports its own unchanged modules
3. **Given** Phase 7 deduplication is complete, **When** the i3 directory is inspected, **Then** `common.nix` contains shared config, `laptop.nix` and `gibson.nix` contain only host-specific deltas merged via the module system
4. **Given** polybar is deduplicated, **When** evaluated for Silicon, **Then** the battery module is present, WiFi module references `wlp0s20f3`, and behavior is identical to before the refactor
5. **Given** a developer wants to add a third host (Carbon), **When** they review the module structure, **Then** they can onboard it by creating a hardware module, host config, and selecting the laptop i3 variant without modifying shared modules
6. **Given** the module reorganization is complete, **When** inspecting the directory structure, **Then** `modules/hosts/` no longer exists, `modules/cluster/` no longer exists, and all modules are under `modules/nixos/`, `modules/home/`, or `modules/hardware/`
7. **Given** Phase 2 is in progress, **When** any commit touches cluster/RPi module files, **Then** only the file path changes — file content is byte-identical to before the move

---

### Edge Cases

- What happens if the NVIDIA driver fails to load? The system should fall back to `nouveau` or at minimum boot to a console TTY, not hang on a black screen.
- What happens if one of the three monitors is disconnected? i3 should gracefully reassign workspaces to the remaining monitors.
- What happens if the Ubuntu NVMe is removed or fails? NixOS should still boot; the `/mnt/ubuntu` mount should be configured with `nofail` so it doesn't block boot.
- What happens if os-prober doesn't detect Ubuntu? A manual GRUB menu entry should be addable as a fallback.
- What happens if a gaming peripheral is not connected at boot? No errors; devices are hot-pluggable via udev.
- What happens if a Phase 2 file move changes Silicon's derivation? The commit MUST be reverted immediately. The move group is investigated before retrying. No "fix forward" — revert first, diagnose second.
- What happens if Phase 7 dedup of a specific module becomes too complex? Operator decides whether to keep independent copies. Agent asks; operator approves or rejects.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST boot NixOS on Gibson hardware (Ryzen 9 5950X, RTX 3080, 64GB RAM) with proprietary NVIDIA drivers loaded
- **FR-002**: System MUST declare a filesystem layout for the 2TB NVMe with a 512MB EFI partition, 32GB swap partition, and the remainder as ext4 root (partitioning is manual operator work during install)
- **FR-003**: System MUST mount the Ubuntu NVMe at `/mnt/ubuntu`, the games NVMe (XFS) at `/srv`, and the HDD at `/mnt/hdd` using `by-uuid` disk identifiers (drives may be moved between slots), with `nofail` mount option on non-root drives
- **FR-004**: System MUST present a GRUB boot menu with NixOS as default and Ubuntu as a selectable option via os-prober
- **FR-005**: System MUST display the i3 window manager across three monitors (27" 1440p center, 24" 1080p left, 24" 1080p right) with workspace-to-monitor assignment: Left = ws 3 (Firefox) + ws 9 (spare), Right = ws 4 (Discord) + ws 10 (spare), Center = ws 1, 2, 5, 6, 7, 8
- **FR-006**: System MUST provide i3 keybindings for directional workspace movement between the three monitors (move workspace left/right)
- **FR-007**: System MUST display polybar on all three monitors, adapted for Gibson (no battery module, correct network interfaces for both ethernet and WiFi)
- **FR-008**: System MUST support Xbox One controllers via the xpadneo driver, primarily over USB (wired) with Bluetooth as a secondary option
- **FR-009**: System MUST support Logitech joysticks via standard HID drivers with full axis and button detection
- **FR-010**: System MUST support the Logitech G29 racing wheel with force feedback via the `new-lg4ff` driver (`hardware.new-lg4ff.enable`)
- **FR-011**: System MUST provide udev rules granting non-root users access to gaming HID devices
- **FR-012**: System MUST include a hardware module (`gibson.nix`) for AMD CPU microcode, NVIDIA GPU configuration using `nvidiaPackages.stable` (with commented `nvidiaPackages.latest` alternative for easy switching), NVIDIA power management enabled for suspend/resume (`nvidia.powerManagement.enable = true`), and desktop-appropriate settings (no TLP, thermald, lid actions, or battery management)
- **FR-013**: System MUST add a `nixosConfigurations.gibson` entry to `flake.nix` without affecting existing Silicon configuration. HLC helper functions (`mkHlcNode`, `mkHlcProvision`, `mkHlcBootstrap`, `mkSdImages`, host lists) MUST be extracted to `lib/hlc.nix` so flake.nix remains pure composition
- **FR-014**: *(Phase 2 — independent copies)* Gibson MUST receive its own independent copy of Silicon's i3 configuration as `modules/home/workstation/i3/gibson.nix`. Silicon's existing i3 config MUST remain untouched (content-unchanged; may be moved to `modules/home/workstation/i3/laptop.nix` as a path-only rename). Both files are complete, standalone i3 configs — no shared extraction at this phase. Host-specific variant is imported in the host's `configuration.nix` via `home-manager.users.eaglerock.imports` alongside `home/eaglerock.nix`
- **FR-014b**: *(Phase 7 — deduplication)* The i3 configuration MUST be deduplicated into three files under `modules/home/workstation/i3/`: `common.nix` (shared keybindings, colors, fonts, gaps, assigns, modes, window commands), `laptop.nix` (Silicon/future laptops: xrandr scaling, brightness keys, xrender picom — reduced to host-specific delta), and `gibson.nix` (triple-monitor xrandr, glx picom, directional workspace movement — reduced to host-specific delta). `workstation.nix` imports `i3/common.nix`; host variants merge on top via the module system
- **FR-015**: *(Phase 2 — independent copies)* Gibson MUST receive its own independent copy of Silicon's polybar configuration. Silicon's polybar MUST remain untouched in content. Gibson's copy is adapted for Gibson-specific differences (no battery module, correct network interfaces, correct default monitor)
- **FR-015b**: *(Phase 7 — deduplication)* The polybar configuration MUST be parameterized to handle host-specific differences via NixOS options defined in a `custom.hostProfile` option set (`hasBattery`, `wlanInterface`, `ethInterface`, `defaultMonitor`). Each host's `configuration.nix` sets these options; polybar reads them via `osConfig`. Single shared polybar module in `modules/home/workstation/`
- **FR-016**: System MUST support both wired ethernet and WiFi via NetworkManager
- **FR-017**: System MUST apply the Gruvbox Dark theme consistently (same as Silicon) across i3, polybar, GTK, terminal, and lock screen
- **FR-018**: System MUST support 5.1 surround audio output (analog multi-channel via motherboard's 3 audio jacks: front, rear, center/sub) and microphone input via onboard motherboard audio through PipeWire with the appropriate surround profile enabled
- **FR-019**: Gibson's i3 startup MUST replicate Silicon's workspace 1 layout (3 alacritty terminals) and floating scratchpad terminal
- **FR-020**: The module directory MUST be reorganized: `modules/hosts/` renamed to `modules/nixos/`, with workstation-specific NixOS modules under `modules/nixos/workstation/` and server modules under `modules/nixos/server/`
- **FR-021**: `modules/cluster/` MUST be absorbed into `modules/nixos/server/` (all files are NixOS system modules), preserving the `hlc/` subdirectory structure
- **FR-022**: `modules/k8s/prereqs.nix` MUST be relocated to `modules/nixos/k8s.nix`, `modules/shell/` to `modules/nixos/shell/`, and `modules/users/operator.nix` to `modules/nixos/operator.nix`
- **FR-023**: `modules/sd/` MUST be relocated to `modules/hardware/rpi/sd/` and existing RPi hardware modules (`rpi4.nix`, `rpi5.nix`, `rpi-eeprom.nix`) MUST be moved under `modules/hardware/rpi/`
- **FR-024**: Workstation-specific home-manager modules (`i3*.nix`, `polybar.nix`, `dunst.nix`, `ui.nix`, `vscode.nix`, `dev.nix`, `layouts/`, `scripts/`) MUST be moved under `modules/home/workstation/`; shared modules (`base.nix`, `colors.nix`), shared support directories (`dotfiles/`, `themes/` — referenced by `base.nix`), and entry points (`workstation.nix`, `server.nix`) stay at `modules/home/` root
- **FR-025**: System MUST support suspend-to-RAM (sleep) but NOT hibernate (suspend-to-disk). The 32GB swap partition serves as runtime swap only, not a resume device. `systemd-logind` suspend-on-idle configuration is out of scope for initial onboarding
- **FR-026**: *(Constitution Principle IX enforcement)* Silicon's evaluated NixOS configuration MUST NOT change at any point during this spec. Every commit that touches shared modules, import paths, or flake-level config MUST be verified with `make dry-run HOST=silicon` producing an identical store path. Zero architectural changes to Silicon — no renderer swaps, no default changes, no "while we're in here" cleanups
- **FR-027**: RPi and cluster node configurations MUST be treated as immutable during this spec. Module files for these hosts MAY be moved to new paths (FR-020–FR-023) but file content MUST be byte-identical before and after. No behavioral changes to non-workstation hosts
- **FR-028**: Phase 2 MUST be broken into ~10 logical move groups, each followed by: (a) `make dry-run HOST=silicon` to verify identical derivation, and (b) an operator visual spot check where the operator logs into Silicon and validates the desktop. Each checkpoint MUST include agent-provided guidance on which Silicon components are most at risk for that move group (e.g., after i3-related moves, check workspaces/keybindings/polybar; after home-manager moves, check alacritty/theming/dunst). The move groups are: (1) NixOS module moves, (2) cluster/server module moves, (3) misc NixOS module moves (k8s, shell, operator), (4) hardware module moves (sd → hardware/rpi/sd), (5) home-manager shared module moves, (6) i3 duplication for Gibson, (7) polybar duplication for Gibson, (8) remaining home module duplications (dunst, picom, etc.), (9) flake.nix changes (add gibson config, extract HLC to lib/hlc.nix), (10) final full validation (both hosts)
- **FR-029**: Each Phase 2 file move MUST be an atomic commit — one logical move per commit. The commit message MUST state what was moved and that content is unchanged. This ensures `git bisect` can pinpoint any regression to a single move. Move Group 9 contains non-move additions (HLC extraction, i3 variant wiring) — these are not subject to the content-unchanged constraint, but Silicon's evaluated config MUST remain an effective no-op after all Group 9 changes
- **FR-030**: *(Phase 7 — deduplication)* ALL modules duplicated in Phase 2 MUST be deduplicated into `common.nix` + host-specific variants, unless the operator judges that a specific dedup is too messy or yields marginal benefit. The decision to keep duplicates for a specific module is an operator judgment call — the agent MUST ask before keeping any module as independent copies. Phase 7 applies to i3, polybar, picom, dunst, and any other module that was copied for Gibson
- **FR-031**: Phase structure MUST be: Phases 1–6 as planned, Phase 7 = code deduplication (MAY run in parallel with Phases 4–6), Phase 8 = polish (formerly Phase 7). Phase 7 dedup work MUST NOT block Gibson-specific work in Phases 4–6

### Key Entities

- **Host (Gibson)**: Desktop workstation — hostname `gibson`, Ryzen 9 5950X, RTX 3080, 64GB RAM, 4 storage drives, 3 monitors
- **Host (Silicon)**: Existing laptop — must remain fully functional after Gibson onboarding
- **Drive Map**: 2TB NVMe (NixOS root), 1TB NVMe (Ubuntu), 1TB NVMe (games/XFS at /srv), HDD (storage at /mnt/hdd)
- **Monitor Layout**: Left 24" 1080p, Center 27" 1440p, Right 24" 1080p — output names discovered during install
- **Gaming Peripherals**: Xbox One controller (xpadneo/Bluetooth), Logitech joysticks (HID), Logitech G29 wheel (lg4ff/force feedback)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Operator can boot Gibson into a working NixOS i3 desktop within one rebuild cycle after initial install
- **SC-002**: All three monitors display content with correct resolution (1440p center, 1080p sides) and workspaces are navigable via keybindings
- **SC-003**: Ubuntu is bootable from the GRUB menu without any modification to the Ubuntu drive
- **SC-004**: All three gaming peripheral types (Xbox controller, Logitech joystick, G29 wheel) are detected and functional in Steam games as a non-root user
- **SC-005**: `make dry-run HOST=silicon` produces an identical store path at every Phase 2 checkpoint and at spec completion. Zero regressions — Silicon's desktop behavior is unchanged throughout. Operator visual spot checks confirm i3, polybar, alacritty, workspaces, and theming are unaffected after each move group
- **SC-006**: After Phase 7 deduplication, Silicon's desktop behavior remains identical to pre-refactor baseline. The i3-laptop/polybar parameterization introduces zero functional change to Silicon
- **SC-007**: Adding a future laptop host requires creating only a hardware module, host config, and selecting the laptop i3 variant — no shared module changes

## Clarifications

### Session 2026-05-18

- Q: Workspace-to-monitor mapping and app assignments? → A: Left monitor: ws 3 (Firefox) + ws 9 (spare). Right monitor: ws 4 (Discord) + ws 10 (spare). Center monitor: ws 1, 2, 5, 6, 7, 8. Same app assignments as Silicon base.
- Q: Disk identifiers → A: All mounts must use `by-uuid` since drives may move between physical slots
- Q: Does Gibson have Bluetooth for Xbox controller? → A: Yes but spotty; controller is usually plugged in via USB. Bluetooth is secondary.
- Q: Root filesystem type for 2TB NVMe? → A: ext4 — simple, proven, matches Silicon
- Q: Audio setup? → A: Onboard motherboard audio, 5.1 surround output with a dedicated microphone
- Q: Wallpaper? → A: Start with Silicon's wallpaper (`wallpaper-gibson.png`), fresh wallpapers to be made later
- Q: Startup layout? → A: Same as Silicon — workspace 1 layout with 3 terminals + floating scratchpad

### Session 2026-05-19 (a)


- Q: Top-level module directory naming — should `modules/hosts/` be renamed? → A: Rename to `modules/nixos/`. Workstation-specific modules under `nixos/workstation/`, server under `nixos/server/`. `common.nix` stays at root. `grub.nix`+`grub/` go into `workstation/`. `k8s/prereqs.nix` → `nixos/k8s.nix`. `shell/` → `nixos/shell/`. `users/operator.nix` → `nixos/operator.nix`. `sd/` → `hardware/rpi/sd/`. `cluster/` absorbed into `nixos/server/`.
- Q: Where do host-specific home-manager modules land? → A: `modules/home/workstation/` for UI modules (i3, polybar, dunst, ui, vscode, dev, layouts, scripts). `modules/home/server/` for server home config. Shared modules (`base.nix`, `colors.nix`), shared support directories (`dotfiles/`, `themes/` — referenced by `base.nix`), and entry points (`workstation.nix`, `server.nix`) stay at `modules/home/` root.
- Q: Should `modules/nixos/server/` be pre-created? → A: Yes, create with `.gitkeep` placeholder now. Populated when first server host is onboarded. `modules/cluster/` content moves here immediately.
- Q: How should host-specific i3/polybar customization be wired to reduce flake.nix complexity? → A: (1) Extract HLC helper functions (`mkHlcNode`, `mkHlcProvision`, `mkHlcBootstrap`, `mkSdImages`, host lists) into `lib/hlc.nix` — flake.nix imports and merges results. (2) `home/eaglerock.nix` is generic for ALL workstations — no host-specific values in it. (3) Host-specific i3 variant imported in the host's `configuration.nix` via `home-manager.users.eaglerock.imports` alongside `eaglerock.nix`. (4) Host-specific polybar values (battery, network interfaces) set as NixOS options in host `configuration.nix`, polybar reads via `osConfig`. No `hostProfile` in flake.nix `extraSpecialArgs`, no dynamic imports. (5) i3 split into three files under `modules/home/workstation/i3/`: `common.nix` (shared ~250 lines: colors, keybindings, fonts, gaps, assigns, modes), `laptop.nix` (laptop xrandr, brightness keys, xrender picom — merged with common via module system, not direct import), `gibson.nix` (triple-monitor xrandr, glx picom, extra workspace movement keybinds — merged with common via module system). `workstation.nix` imports `i3/common.nix`; variant files merge on top. flake.nix stays pure composition.
- Q: Should HLC helpers live in `lib/hlc.nix` or `modules/helpers/hlc.nix`? → A: `lib/hlc.nix` — follows nixpkgs convention where `lib/` holds pure utility functions and `modules/` is reserved for NixOS module-system participants (things with `options`/`config`). HLC helpers are builder functions, not modules.
- Q: Which NVIDIA driver package variant? → A: `nvidiaPackages.stable` as default, but hardware module should make it easy to switch to `nvidiaPackages.latest` (single-line change, commented alternative).
- Q: Multi-monitor partial failure during i3 startup? → A: Let i3/xrandr fail gracefully — i3 starts on whatever monitors xrandr succeeds on. No custom retry logic or autorandr profiles.

### Session 2026-05-19 (b)

- Q: Does Gibson suspend/hibernate or shutdown only? → A: Suspend-to-RAM (sleep) supported, no hibernate. NVIDIA power management enabled for clean suspend/resume. 32GB swap is runtime-only, not a resume device.
- Q: How does Gibson output 5.1 surround audio? → A: Analog multi-channel from motherboard (3 jacks: front, rear, center/sub). PipeWire with surround profile, no HDMI audio or external receiver.

### Session 2026-05-21

- Q: Phase 2 Silicon isolation — can Silicon files be moved/renamed? → A: Yes, file moves allowed if content unchanged, each move is atomic commit, verified with `make dry-run HOST=silicon`. Gibson gets independent copies of modules it needs.
- Q: What constitutes a visual spot check and how often? → A: `make dry-run` after every commit + operator visual check after every logical move group (~10 checkpoints). Each checkpoint includes guidance on which Silicon components to validate most.
- Q: Should FR-014 (i3 split) be split into Phase 2 and Phase 7? → A: Yes. Phase 2 FR = independent copies (Gibson gets full copy, Silicon untouched). Phase 7 FR = deduplication into common.nix + host deltas. Same treatment for polybar and other duplicated modules.
- Q: Phase 7 deduplication scope — all modules or selective? → A: All duplicated modules, but operator may decide case-by-case to keep duplicates where dedup is too messy. This is an operator judgment call — agent must ask.
- Q: Phase 2 sub-phase grouping? → A: ~10 groups: (1) NixOS module moves, (2) cluster/server moves, (3) misc NixOS moves, (4) hardware moves, (5) home shared moves, (6) i3 duplication, (7) polybar duplication, (8) remaining home duplications, (9) flake.nix changes, (10) final validation. RPi/cluster configs are immutable — content-unchanged moves only.

## Assumptions

- The operator will perform the NixOS installation manually (boot from USB, partition the 2TB NVMe, run `nixos-install`) — this spec covers the configuration, not the installation procedure
- GPU output names (DP-0, DP-1, HDMI-0, etc.) will be discovered during initial install via `xrandr` and hardcoded into `i3/gibson.nix`
- The Ubuntu installation uses a standard EFI/GRUB setup that os-prober can detect
- The existing XFS games partition at `/srv` contains a Steam library that Steam on NixOS can adopt by adding the library path
- The Logitech G29's RPM indicator LEDs are out of scope for initial onboarding (nice-to-have for a follow-up)
- Kubernetes cluster functionality is out of scope — will be a separate future specification
- The future Carbon laptop (X1 Carbon Gen6) onboarding is out of scope but the architecture should not preclude it
