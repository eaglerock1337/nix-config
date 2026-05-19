# Research: Gibson NixOS Desktop Onboarding

**Date**: 2026-05-19 | **Branch**: `002-gibson-nixos-onboard`

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

**Screen tearing**: Use picom with `vsync = true` and `backend = "glx"`. Do NOT use `forceFullCompositionPipeline` on a triple-monitor setup.

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

**Decision**: Use NixOS custom options (`custom.hostProfile`) read via `osConfig` in home-manager modules

**Rationale**: Defines typed options in the NixOS workstation module (`modules/nixos/workstation.nix`). Each host's `configuration.nix` sets concrete values. Home-manager modules access via `osConfig.custom.hostProfile.*`. Type-checked at evaluation time — bad values fail the build, not silently produce wrong config. Keeps flake.nix as pure composition with no host-specific data.

**Option definition** (in `modules/nixos/workstation.nix`):
```nix
options.custom.hostProfile = {
  hasBattery = lib.mkOption { type = lib.types.bool; default = false; };
  wlanInterface = lib.mkOption { type = lib.types.str; default = ""; };
  ethInterface = lib.mkOption { type = lib.types.str; default = ""; };
  defaultMonitor = lib.mkOption { type = lib.types.str; default = "eDP-1"; };
};
```

**Host usage** (in `hosts/silicon/configuration.nix`):
```nix
custom.hostProfile = {
  hasBattery = true;
  wlanInterface = "wlp0s20f3";
  defaultMonitor = "eDP-1";
};
```

**Polybar usage** (in `modules/home/workstation/polybar.nix`):
```nix
{ osConfig, lib, ... }:
let hostProfile = osConfig.custom.hostProfile; in
# lib.optionals hostProfile.hasBattery [...]
# hostProfile.wlanInterface for network module
```

**Alternatives considered**:
- `extraSpecialArgs` with `hostProfile` attrset — simpler but not type-checked, mixes host data into flake.nix, requires flake.nix changes per host
- Per-host home-manager entry points — fights the module system, duplicates import chains

## R-004: Picom Configuration for NVIDIA Triple-Monitor

**Decision**: Use `glx` backend with `vsync = true` and NVIDIA-specific flags

**Rationale**: The current config uses `backend = "xrender"` and `vsync = false`, which is a CPU-based fallback. With NVIDIA proprietary drivers, `glx` is the performant backend. `use-damage = false` prevents corruption/flickering artifacts common with NVIDIA + glx. `unredir-if-possible = false` prevents tearing when picom unredirects fullscreen windows on multi-monitor.

**Key settings**:
```
backend = "glx";
vsync = true;
use-damage = false;
unredir-if-possible = false;
```

**forceFullCompositionPipeline**: Confirmed — still avoid on multi-monitor. When picom handles compositing, ForceFullCompositionPipeline in xorg.conf duplicates vsync and causes latency. NVIDIA developer forum threads confirm bugs in newer drivers.

**Tradeoff**: `glx` uses ~35MB more RAM than `xrender` and grows over time. Negligible on 64GB.

## R-005: Module Reorganization — Import Path Impact

**Decision**: Reorganize modules in a dedicated phase (Phase 1) before any Gibson-specific additions. Extract HLC helpers to `lib/hlc.nix`.

**Rationale**: Mixing structural changes with feature additions makes regression isolation impossible. The reorg touches 10 files with functional imports and several files with comments/documentation references.

**Files with functional import paths to update** (10 unique files):
1. `hosts/silicon/configuration.nix` — 4 imports (hosts/ → nixos/)
2. `modules/hosts/common.nix` → `modules/nixos/common.nix` — 3 imports (shell/, users/)
3. `modules/cluster/common.nix` → `modules/nixos/server.nix` — 3 imports (hosts/, k8s/)
4. `modules/cluster/hlc/default.nix` → `modules/nixos/server/hlc/default.nix` — 1 import (../common.nix)
5. `modules/cluster/hlc/provision.nix` → `modules/nixos/server/hlc/provision.nix` — 1 import (users/)
6. `modules/sd/recovery-utils.nix` → `modules/hardware/rpi/sd/recovery-utils.nix` — 1 import (cluster/)
7. `flake.nix` — 3 imports (cluster/, sd/) + HLC helper extraction to `lib/hlc.nix`
8. `modules/home/workstation.nix` — imports change (i3.nix → workstation/i3/common.nix, others → workstation/)
9. `modules/home/workstation/dunst.nix` — 1 import (colors.nix → ../colors.nix)
10. `modules/home/workstation/polybar.nix` — 1 import (colors.nix → ../colors.nix)

**HLC extraction**: flake.nix currently has ~80 lines of inline HLC helper definitions (mkHlcNode, mkHlcProvision, mkHlcBootstrap, mkSdImages, pi4Hosts, pi5Hosts). These move to `lib/hlc.nix` so flake.nix stays pure composition. See R-009.

**Shared file boundary issue**: `dotfiles/` and `themes/` directories are referenced by `base.nix` (shared) for vim config. These directories stay at `modules/home/` root. Only `layouts/` and `scripts/` move to `modules/home/workstation/` since they're referenced exclusively by workstation modules (`i3.nix`, `ui.nix`).

**New directories**: `modules/home/server/` created with `.gitkeep` placeholder for future server home-manager modules.

**Validation**: After reorg, every existing nixosConfiguration must evaluate identically. Test with `nix flake check` and spot-check `nixos-rebuild dry-run --flake .#silicon`.

## R-006: Constitution Compliance Notes

**Principle VII impact**: The constitution's host capability table lists Gibson as a build host (Ubuntu, no `nixos-rebuild`). After this feature, Gibson will have NixOS. The table must be updated post-install (PATCH bump to constitution version).

**Unfree additions**: `nvidia-x11` and `nvidia-settings` must be added to the unfree allowlist with justification in the commit message (Principle VI).

**Principle III**: The module reorganization directly improves compliance — clearer separation of concerns, better naming.

## R-008: i3 Split Architecture

**Decision**: Split i3 into three files in `modules/home/workstation/i3/` subdirectory; variant wired via `home-manager.users.eaglerock.imports` in host config

**Rationale**: Current `i3.nix` is ~350 lines mixing shared config (keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout — ~250 lines) with Silicon-specific hardware setup (xrandr, brightness keys, xrender picom — ~100 lines). Splitting allows Gibson to reuse all shared config while specifying its own hardware-specific settings.

**File structure**:
- `i3/common.nix` — shared keybindings, colors, fonts, gaps, assigns, modes, window commands, startup layout (3 terminals + scratchpad). Imported by `workstation.nix` for all workstations
- `i3/laptop.nix` — Silicon/future laptops: xrandr scaling, brightness keys, xrender picom. Does NOT import common.nix (it merges as a separate module)
- `i3/gibson.nix` — triple-monitor xrandr, glx picom, directional workspace movement keybindings. Does NOT import common.nix (it merges as a separate module)

**Wiring**: `workstation.nix` imports `./workstation/i3/common.nix`. Host-specific variant imported in each host's `configuration.nix` via:
```nix
home-manager.users.eaglerock.imports = [
  ../../modules/home/workstation/i3/laptop.nix  # Silicon
];
```
This merges with the `home-manager.users.eaglerock = import ./home/eaglerock.nix` in flake.nix via NixOS module system merging.

**Why subdirectory**: Three related files warrant a directory. Matches existing `grub/` pattern.

**Why not dynamic import via string interpolation**: `./i3-${variant}.nix` in Nix imports is fragile — import paths are resolved at parse time. Explicit import in host config is transparent and lets `nix flake check` trace all imports statically.

**Picom deduplication**: Currently duplicated in i3.nix and polybar.nix. After split, picom config lives only in variant files (different backends per GPU). Remove from polybar.nix entirely. If ui.nix also enables `services.picom`, reconcile to avoid conflict with manual config.

## R-009: HLC Helper Extraction to lib/hlc.nix

**Decision**: Extract all HLC-related helper functions and host lists from flake.nix to `lib/hlc.nix`

**Rationale**: flake.nix currently has ~80 lines of inline HLC helper definitions that are unrelated to Gibson onboarding but clutter the composition layer. Extracting them makes flake.nix a pure composition file — just inputs, hosts, and merges.

**Pattern**:
```nix
# lib/hlc.nix — receives flake inputs, returns helper set
{ nixpkgs, home-manager, nixos-raspberrypi, disko, sops-nix, operatorPubkeys }:
let
  mkHlcNode = { hostPath, extraModules ? [] }: ...;
  mkHlcProvision = { hostPath, extraModules ? [] }: ...;
  mkHlcBootstrap = { hostname, piModule }: ...;
  mkSdImages = piModule: hosts: ...;
  pi4Hosts = [ "hlc-401" "hlc-402" "hlc-403" "hlc-404" ];
  pi5Hosts = map (n: "hlc-5${toString (n + 0)}") (lib.range 1 8);
in { inherit mkHlcNode mkHlcProvision mkHlcBootstrap mkSdImages pi4Hosts pi5Hosts; }
```

```nix
# flake.nix — import and use
let
  hlc = import ./lib/hlc.nix { inherit nixpkgs home-manager ...; };
in {
  nixosConfigurations = {
    silicon = ...;
    gibson = ...;
  } // (builtins.listToAttrs (map (h: { name = h; value = hlc.mkHlcNode { ... }; }) ...));
}
```

**Alternatives considered**:
- Keep inline — works but flake.nix grows with every cluster change
- Flake parts / flake-utils — heavier dependency for a single extraction

## R-007: PipeWire 5.1 Surround Sound — AMD Onboard Audio

**Decision**: Use `services.pipewire.wireplumber.extraConfig` to pin surround profile and demote NVIDIA HDMI sink priority

**Rationale**: PipeWire + WirePlumber does NOT auto-select the 5.1 profile. The ACP layer enumerates all available profiles and WirePlumber defaults to the highest-priority stereo profile ("Analog Stereo Duplex"). The surround profile (`output:analog-surround-51+input:analog-stereo`) must be explicitly declared. Additionally, with an NVIDIA GPU, HDMI audio often wins the default sink election. Both issues need declarative fixes.

**Key configuration** (in `modules/hardware/gibson.nix`):
- Rule `"90-onboard-surround"` under `services.pipewire.wireplumber.extraConfig`: match `device.name = "~alsa_card.pci.*"` + `device.nick = "~HD-Audio*"`, set `device.profile = "output:analog-surround-51+input:analog-stereo"` (covers mic input via the `+input:analog-stereo` suffix)
- Rule `"91-nvidia-sink-priority"`: match `node.name = "~alsa_output.*HDMI*"`, lower `priority.driver` and `priority.session` to 500 (default is 1000; onboard analog keeps 1000)
- Profile name caveat: `output:analog-surround-51+input:analog-stereo` is canonical for Intel HDA codecs (Realtek ALC1220/ALC892). Verify post-install with `pactl list cards`

**Why `extraConfig` over alternatives**:
- `configPackages` — for pre-built derivations, more boilerplate, no advantage here
- `environment.etc` with WirePlumber Lua — deprecated 0.4 pattern; WirePlumber 0.5 (NixOS 25.11) uses SPA-JSON `.conf` files
- `pactl set-card-profile` in startup script — imperative, not reproducible

**NVIDIA HDMI coexistence**: Both devices remain visible and selectable. Priority rules make onboard the default. To fully disable NVIDIA HDMI if never needed, match `device.name = "~alsa_card.pci-*nvidia*"` and set `device.profile = "off"`.
