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

The NixOS configuration cleanly supports both Silicon (laptop) and Gibson (desktop) from the same flake, with shared modules for common functionality and separate modules where hardware differs. The i3 configuration is split into laptop and desktop variants. Polybar is parameterized to adapt to host-specific differences (monitors, network interfaces, battery presence). The architecture prepares for a future third laptop host (Carbon).

**Why this priority**: Good architecture prevents configuration drift and makes future host onboarding cheaper. Not blocking for Gibson itself but improves long-term maintainability.

**Independent Test**: Both `nixos-rebuild dry-run --flake .#silicon` and `nixos-rebuild dry-run --flake .#gibson` succeed, importing the correct host-specific modules.

**Acceptance Scenarios**:

1. **Given** the flake defines both `silicon` and `gibson`, **When** the configuration is evaluated, **Then** Silicon imports `i3-laptop.nix` and Gibson imports `i3-gibson.nix`
2. **Given** polybar.nix is parameterized, **When** evaluated for Gibson, **Then** the battery module is absent, and network modules reference Gibson's interfaces
3. **Given** polybar.nix is parameterized, **When** evaluated for Silicon, **Then** the battery module is present, WiFi module references `wlp0s20f3`, and behavior is identical to before the refactor
4. **Given** a developer wants to add a third host (Carbon), **When** they review the module structure, **Then** they can onboard it by creating a hardware module, host config, and selecting `i3-laptop.nix` without modifying shared modules

---

### Edge Cases

- What happens if the NVIDIA driver fails to load? The system should fall back to `nouveau` or at minimum boot to a console TTY, not hang on a black screen.
- What happens if one of the three monitors is disconnected? i3 should gracefully reassign workspaces to the remaining monitors.
- What happens if the Ubuntu NVMe is removed or fails? NixOS should still boot; the `/mnt/ubuntu` mount should be configured with `nofail` so it doesn't block boot.
- What happens if os-prober doesn't detect Ubuntu? A manual GRUB menu entry should be addable as a fallback.
- What happens if a gaming peripheral is not connected at boot? No errors; devices are hot-pluggable via udev.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST boot NixOS on Gibson hardware (Ryzen 9 5950X, RTX 3080, 64GB RAM) with proprietary NVIDIA drivers loaded
- **FR-002**: System MUST partition the 2TB NVMe with a 512MB EFI partition, 32GB swap partition, and the remainder as ext4 root
- **FR-003**: System MUST mount the Ubuntu NVMe at `/mnt/ubuntu`, the games NVMe (XFS) at `/srv`, and the HDD at `/mnt/hdd` using `by-uuid` disk identifiers (drives may be moved between slots), with `nofail` mount option on non-root drives
- **FR-004**: System MUST present a GRUB boot menu with NixOS as default and Ubuntu as a selectable option via os-prober
- **FR-005**: System MUST display the i3 window manager across three monitors (27" 1440p center, 24" 1080p left, 24" 1080p right) with workspace-to-monitor assignment: Left = ws 3 (Firefox) + ws 9 (spare), Right = ws 4 (Discord) + ws 10 (spare), Center = ws 1, 2, 5, 6, 7, 8
- **FR-006**: System MUST provide i3 keybindings for directional workspace movement between the three monitors (move workspace left/right)
- **FR-007**: System MUST display polybar on all three monitors, adapted for Gibson (no battery module, correct network interfaces for both ethernet and WiFi)
- **FR-008**: System MUST support Xbox One controllers via the xpadneo driver, primarily over USB (wired) with Bluetooth as a secondary option
- **FR-009**: System MUST support Logitech joysticks via standard HID drivers with full axis and button detection
- **FR-010**: System MUST support the Logitech G29 racing wheel with force feedback via the lg4ff kernel module
- **FR-011**: System MUST provide udev rules granting non-root users access to gaming HID devices
- **FR-012**: System MUST include a hardware module (`gibson.nix`) for AMD CPU microcode, NVIDIA GPU configuration, and desktop-appropriate settings (no laptop power management)
- **FR-013**: System MUST add a `nixosConfigurations.gibson` entry to `flake.nix` without affecting existing Silicon configuration
- **FR-014**: The i3 configuration MUST be split into `i3-laptop.nix` (for Silicon and future laptops) and `i3-gibson.nix` (for Gibson's triple-monitor layout)
- **FR-015**: The polybar configuration MUST be parameterized to handle host-specific differences (monitor names, network interfaces, battery presence) from a single shared module
- **FR-016**: System MUST support both wired ethernet and WiFi via NetworkManager
- **FR-017**: System MUST apply the Gruvbox Dark theme consistently (same as Silicon) across i3, polybar, GTK, terminal, and lock screen
- **FR-018**: System MUST support 5.1 surround audio output and microphone input via onboard motherboard audio through PipeWire
- **FR-019**: Gibson's i3 startup MUST replicate Silicon's workspace 1 layout (3 alacritty terminals) and floating scratchpad terminal

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
- **SC-005**: Silicon's `nixos-rebuild dry-run` produces identical results before and after Gibson onboarding (zero regression)
- **SC-006**: The i3-laptop/i3-gibson split and polybar parameterization result in no functional change to Silicon's desktop behavior
- **SC-007**: Adding a future laptop host requires creating only a hardware module, host config, and selecting the laptop i3 variant — no shared module changes

## Clarifications

### Session 2026-05-18

- Q: How should workspaces be distributed across Gibson's three monitors? → A: Left: ws 3 (Firefox) + ws 9 (spare). Right: ws 4 (Discord) + ws 10 (spare). Center: ws 1, 2, 5, 6, 7, 8.
- Q: Disk identifiers → A: All mounts must use `by-uuid` since drives may move between physical slots
- Q: Does Gibson have Bluetooth for Xbox controller? → A: Yes but spotty; controller is usually plugged in via USB. Bluetooth is secondary.
- Q: Root filesystem type for 2TB NVMe? → A: ext4 — simple, proven, matches Silicon
- Q: Audio setup? → A: Onboard motherboard audio, 5.1 surround output with a dedicated microphone
- Q: Wallpaper? → A: Start with Silicon's wallpaper (`wallpaper-gibson.png`), fresh wallpapers to be made later
- Q: Startup layout? → A: Same as Silicon — workspace 1 layout with 3 terminals + floating scratchpad
- Q: App-to-workspace assignments? → A: Same as Silicon base. Firefox stays on workspace 3, Discord stays on workspace 4. Workspaces 9 and 10 are dedicated spare workspaces for side monitors.
- Q: Workspace-to-monitor mapping? → A: Left monitor: ws 3 (Firefox) + ws 9 (spare). Right monitor: ws 4 (Discord) + ws 10 (spare). Center monitor: ws 1, 2, 5, 6, 7, 8.

## Assumptions

- The operator will perform the NixOS installation manually (boot from USB, partition the 2TB NVMe, run `nixos-install`) — this spec covers the configuration, not the installation procedure
- GPU output names (DP-0, DP-1, HDMI-0, etc.) will be discovered during initial install via `xrandr` and hardcoded into `i3-gibson.nix`
- The Ubuntu installation uses a standard EFI/GRUB setup that os-prober can detect
- The existing XFS games partition at `/srv` contains a Steam library that Steam on NixOS can adopt by adding the library path
- The Logitech G29's RPM indicator LEDs are out of scope for initial onboarding (nice-to-have for a follow-up)
- Kubernetes cluster functionality is out of scope — will be a separate future specification
- The future Carbon laptop (X1 Carbon Gen6) onboarding is out of scope but the architecture should not preclude it
