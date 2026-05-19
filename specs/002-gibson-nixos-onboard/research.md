# Research: Gibson NixOS Desktop Onboarding

**Date**: 2026-05-18 | **Branch**: `002-gibson-nixos-onboard`

## R-001: NVIDIA RTX 3080 on NixOS 25.11

**Decision**: Use proprietary NVIDIA drivers with open kernel modules (`hardware.nvidia.open = true`)

**Rationale**: RTX 3080 is Ampere architecture — NVIDIA recommends open kernel modules for Turing and newer. The stable branch on 25.11 ships driver 580.119.02 with full Ampere support. Even with open kernel modules, the userspace blob is proprietary, so unfree allowlist entries are still required.

**Key configuration**:
- `services.xserver.videoDrivers = [ "nvidia" ]` — activates the module
- `hardware.nvidia.open = true` — open kernel modules (recommended for Ampere)
- `hardware.nvidia.modesetting.enable = true` — default on 25.11 but good to state explicitly
- `hardware.nvidia.powerManagement.enable = true` — handles suspend correctly on desktop
- `hardware.nvidia.forceFullCompositionPipeline = false` — known to break multi-monitor (nixpkgs #261112); use picom vsync instead
- `hardware.graphics.enable = true` + `hardware.graphics.enable32Bit = true` — required for Vulkan + Steam/Proton
- Unfree allowlist: `nvidia-x11`, `nvidia-settings`

**Screen tearing**: Use picom with `vsync = true` and `backend = "glx"` (already used on Silicon). Do NOT use `forceFullCompositionPipeline` on a triple-monitor setup.

**Alternatives considered**:
- `nouveau` — insufficient for gaming, no Vulkan
- NVK (Mesa open Vulkan) — not production-ready for RTX 3080
- Closed kernel modules (`hardware.nvidia.open = false`) — would work but NVIDIA recommends open for Ampere

## R-002: Gaming Peripherals on NixOS 25.11

### Xbox One Controller (xpadneo)

**Decision**: Use `hardware.xpadneo.enable = true`

**Rationale**: Option exists in nixpkgs 25.11, installs `hid_xpadneo` DKMS module (v0.9.7). Handles Bluetooth connections with vibration support. For wired USB, the in-kernel `xpad` driver handles it automatically. Both coexist.

### Logitech G29 Racing Wheel

**Decision**: Use `hardware.new-lg4ff.enable = true`

**Rationale**: In-kernel `lg4ff` provides basic force feedback but limited effect types. `new-lg4ff` (available in nixpkgs 25.11 as `hardware.new-lg4ff.enable`) replaces the in-kernel driver with enhanced FFB: spring, damper, friction, inertia effects, lower latency, and sysfs-based gain tuning. G29 is in the supported device list.

**udev rules**: `TAG+="uaccess"` on vendor `046d` product `c24f` grants access to the active console user. `oversteer` package (v0.8.3 in nixpkgs) provides a GUI for rotation range and FFB gain tuning.

### Logitech Joysticks

**Decision**: Standard HID support sufficient — no extra configuration needed

**Rationale**: `hid-logitech` and `joydev` modules load automatically via udev when a Logitech joystick is plugged in.

### Steam Hardware udev Rules

**Decision**: Already handled by `programs.steam.enable`

**Rationale**: The Steam NixOS module automatically sets `hardware.steam-hardware.enable = true`, which installs comprehensive udev rules covering Steam Controller, PS4/PS5, Switch Pro, 8BitDo, and many others. It also loads the `uinput` kernel module.

### Testing Tools

Available in nixpkgs: `evtest` (raw input), `linuxConsoleTools` (jstest/fftest), `jstest-gtk` (GUI), `oversteer` (wheel GUI).

## R-003: Polybar Parameterization

**Decision**: Use `extraSpecialArgs` with a `hostProfile` attrset

**Rationale**: The flake already uses `home-manager.extraSpecialArgs = { inherit unstable; }`. Extending this with a `hostProfile` attrset is the minimal-boilerplate approach. Each host defines its profile inline in `flake.nix`. Polybar.nix receives `hostProfile` in its function args and uses `lib.optionalAttrs` / `lib.optionals` for conditional sections.

**Profile keys needed**:
- `hasBattery` (bool)
- `wlanInterface` (string)
- `ethInterface` (string, empty if none)
- `defaultMonitor` (string)

**Conditional patterns**:
- `lib.optionals hostProfile.hasBattery [...]` for module lists
- `lib.optionalAttrs hostProfile.hasBattery { "module/battery" = {...}; }` for config sections
- `"\${env:MONITOR:${hostProfile.defaultMonitor}}"` for monitor default

**Alternatives considered**:
- Custom NixOS options via `osConfig` — more boilerplate, overkill for ~4 keys
- Per-host home-manager entry points — fights the module system, duplicates import chains

## R-004: Constitution Compliance Notes

**Principle VII impact**: The constitution's host capability table lists Gibson as a build host (Ubuntu, no `nixos-rebuild`). After this feature, Gibson will have NixOS. The table must be updated post-install. Until NixOS is installed, the Gibson config can be build-validated on Silicon using `nixos-rebuild dry-run --flake .#gibson` (same x86_64 architecture).

**Unfree additions**: `nvidia-x11` and `nvidia-settings` must be added to the unfree allowlist with justification in the commit message (Principle VI).
