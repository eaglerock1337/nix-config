# Phase 0 Research: NixOS RPi Cluster Foundation (v2)

**Date**: 2026-04-29
**Spec**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

This document resolves the technical unknowns surfaced by the spec and the plan's Technical Context, and records the rationale for each decision so it survives future revisitation.

---

## R-001 — Upstream Pi NixOS source: which fork, which branch, which revision

**Decision**: Use `github:nvmd/nixos-raspberrypi`, branch `main`, pinned to a specific commit selected at flake-update time. The repo's `develop` branch is consulted for documentation only and not used as a flake input.

**Rationale**:

- The post-mortem identifies `nix-community/raspberry-pi-nix` (the current `flake.nix` input) as archived; ongoing Pi-5 work has moved to nvmd's fork. This is the proximate cause of the prior incident: the previous attempt fought stale upstream behavior because the upstream itself was unmaintained.
- nvmd's `main` branch is the recommended consumption point per the project's README; `develop` is the active integration branch. Pinning `main` gives us latest-stable behavior without exposure to in-flight changes.
- Pinning to a specific commit (rather than a moving branch ref) is required by Constitution Principle II (Reproducibility via Flakes). `nix flake update` is the supported path to advance the pin.

**Alternatives considered**:

- Stay on `nix-community/raspberry-pi-nix`: rejected — archived, missing Pi 5 fixes that nvmd has merged.
- Pin nvmd's `develop` branch: rejected — exposes us to in-flight upstream changes; conflicts with the safety-first posture of Constitution IV.
- Use upstream NixOS `nixos-hardware` Pi 5 modules without the nvmd fork: rejected — `nixos-hardware`'s Pi 5 support is incomplete; nvmd specifically targets the gaps. We continue to use `nixos-hardware` for the generic Pi modules layered on top of nvmd.

**Open follow-ups**:

- A flake-update task in `/speckit-tasks` will run `nix flake update raspberrypi-nvmd` (or whatever the input is named on swap) and record the resulting `flake.lock` revision in the commit message.

---

## R-002 — Mountain-glyph (`⛰`, U+26F0) presentation strategy

**Decision**: Append the Unicode variation selector `U+FE0E` (text presentation) immediately after `⛰` in the PS1 template, producing the byte sequence `⛰︎`. If a terminal still renders it as emoji (some kitty builds, some macOS Terminal versions), fall back at module-evaluation time to the ASCII triangle `▲` controlled by an `hlc.prompt.mountainGlyph` NixOS option.

**Rationale**:

- `⛰` U+26F0 has a default emoji presentation in many fonts; `︎` (VARIATION SELECTOR-15) explicitly requests text presentation, which most modern terminals honor.
- Rendering as an emoji has two side effects: variable cell width (some terminals render emoji as double-width) and color override (the terminal forces a color even when the surrounding string has none, breaking FR-017's "no color in remote form" rule).
- A NixOS option (`hlc.prompt.mountainGlyph`) makes the fallback declarative: if a particular operator's terminal does not honor `︎`, they can flip the option for their own host without forking the module.

**Alternatives considered**:

- Use only ASCII (`▲`) from the start: rejected — loses the Bob Ross-mountain feel the operator chose explicitly.
- Wrap `⛰` in escape sequences (e.g. `\e[39m⛰\e[39m`) to suppress emoji color: rejected — does not work on terminals that auto-promote to emoji presentation; also violates FR-017 no-color rule for the remote form.
- Use a different mountain glyph (e.g. `🗻` or `▲`): rejected — `🗻` is also default-emoji; `▲` is the documented fallback, not the primary.

**Open follow-ups**:

- Phase 5 task to validate rendering on the operator's terminals (kitty on `gibson`, default `xterm-256color` over SSH from a fresh shell, plain `TERM=xterm`).

---

## R-003 — k3s service unit: enabled-but-stopped pattern in NixOS

**Decision**: Use `services.k3s.enable = true` to install the package and create the systemd unit, then add a NixOS module setting `systemd.services.k3s.wantedBy = lib.mkForce [ ];` so the unit exists but is not pulled in by `multi-user.target`. This matches User Story 5 acceptance scenario 2: the unit is enabled (by `services.k3s.enable`) but does not start at boot. The follow-on cluster-bootstrap spec will replace `wantedBy = [ ]` with the default `[ "multi-user.target" ]` and supply server/agent configuration.

**Rationale**:

- `services.k3s` from upstream NixOS provides the canonical k3s integration (binary, kernel module hints, sysctl recommendations). Using a custom unit would diverge from upstream and lose those defaults.
- `wantedBy = [ ]` is the documented NixOS idiom for "package + unit installed, never auto-started." Combined with no `services.k3s.serverAddr` / `services.k3s.tokenFile` configuration, the service has nothing to start with even if invoked manually.
- A separate sentinel file (`/var/lib/rancher/k3s/.disabled`) would also work but adds a non-declarative artifact, which violates Principle I.

**Alternatives considered**:

- `services.k3s.enable = false` + manual package install: rejected — loses the upstream integration (kernel modules, sysctls, sd-card-friendly defaults).
- Run k3s in single-node mode on each box and migrate later: rejected during clarification (Q1, Option C); the spec commits to "no cluster state on disk yet."
- Use a custom systemd unit override file: rejected — duplicates upstream's work, harder to audit, no advantage over `mkForce`.

**Open follow-ups**:

- Cross-check upstream `services.k3s` for any additional `wantedBy` or `requiredBy` sets that need overriding.

---

## R-004 — Disko schemas: Pi 4 vs Pi 5 (USB RAID1 root, NVMe data, SD recovery)

**Decision**: Two disko schemas — `disko/rpi4.nix` and `disko/rpi5.nix`. Both define `/boot` on the SD-card device and `/` on a 2-disk mdadm RAID1 across the two USB drives (single partition, full array; drives are ~30 GB / ~28.6 GiB usable — too small to split further). `disko/rpi5.nix` additionally defines `/srv/ssd` on the NVMe device. Filesystems: ext4 for `/` (durability, journaling, well-understood recovery); xfs for `/srv/ssd` (better for large-file Longhorn workloads, though Longhorn itself is out of scope for this spec — picking xfs now keeps the option open). Device names are passed in via NixOS module arguments (`config.hlc.disko.usbDevice0`, `usbDevice1`, `nvmeDevice`) so they can be overridden per host where physical layout differs.

**Rationale**:

- USB RAID1 mirror for `/` matches FR-010 and the durability requirement: a single USB-drive failure must not take a node down.
- Single partition (no `/srv/usb` split): drives are ~30 GB / ~28.6 GiB; splitting would leave ~8 GiB for workload data which is not useful. Full array used for `/`. `/srv/usb` partition dropped 2026-05-05 (confirmed during first provision attempt — sgdisk rejected the 50G partition size on ~28.6 GiB device).
- mdadm (rather than ZFS or btrfs RAID): operator's existing toolchain expectation per post-mortem; mdadm's failure modes are well-understood; both ZFS and btrfs raise complexity (kernel module licensing for ZFS; btrfs RAID1 still has known caveats on small disks).
- ext4 for `/`: smallest blast radius. xfs on `/srv/ssd` because the NVMe is intended for high-throughput workload data later (Longhorn, databases) and xfs scales better for large files.
- Device-name parameterization is the same pattern silicon already uses for hardware-specific values; keeps the disko schemas reusable without per-host duplication.

**Alternatives considered**:

- Single shared disko schema with conditionals: rejected — Pi 4 / Pi 5 differ enough (NVMe presence) that two schemas are clearer than one branchy schema.
- ZFS for `/`: rejected for complexity (CDDL/GPL friction in NixOS, kernel-module dependency on aarch64).
- btrfs RAID1: rejected for not-yet-mature behavior on degraded mounts.
- ext4 across all three filesystems: acceptable fallback if xfs surprises us; flagged as a trivial revert path.

**Open follow-ups**:

- Confirm NVMe device path on Pi 5 with `nvmd` kernel: typically `/dev/nvme0n1`. To be verified on `hlc-501` during Phase 4 canary.
- Confirm USB drive device names are stable across boots (the `/dev/disk/by-id/` paths will be used in the disko schemas, not `/dev/sd*`, to avoid renumbering issues).

---

## R-005 — Boot order: USB-first, SD recovery fallback (FR-011)

**Decision**: Two-layer approach.

1. Pi firmware EEPROM `BOOT_ORDER` set to prefer USB (`0xf14` — try USB first, then SD, repeating). The SD card itself remains a fallback boot medium. EEPROM updates are performed once per Pi during the SD baseline boot via `rpi-eeprom-config`, captured in a NixOS module `modules/hardware/rpi-eeprom.nix`.
2. The SD card carries the bootstrap NixOS image at all times. After provisioning, the SD card's `/boot` is updated to chain into the USB array's root. If the USB array is absent (drives removed or RAID degraded beyond mount), the firmware falls back to the SD card's standalone bootstrap configuration (which has its own root inside the SD's `/`), giving the operator a recovery shell with `mdadm` available.

**Rationale**:

- The EEPROM `BOOT_ORDER` is the only mechanism by which Pi firmware decides what to try first; a NixOS-side bootloader cannot override what the firmware does at power-on.
- Keeping the SD card permanently in the slot (not just for first-boot) is the only way to get a headless recovery path. The post-mortem treats this as a hard requirement.
- The SD's bootstrap root is small and self-contained; it does not need to mirror per-host service configuration. This is the same separation FR-003 mandates for the bootstrap image.

**Alternatives considered**:

- USB-only boot, SD removed after provisioning: rejected — no headless recovery story; matches the failure mode the post-mortem warns about.
- Network PXE boot for recovery: rejected for complexity and added dependency on the upstream network being healthy at recovery time.

**Open follow-ups**:

- Verify `BOOT_ORDER = 0xf14` is the right value on both Pi 4 (bcm2711) and Pi 5 (bcm2712) bootloaders; the encoding is the same but the EEPROM ages differ.
- Decide whether the SD bootstrap config gets `nixos-rebuild` updates over time, or is treated as a frozen recovery image (operator preference; default to "frozen, only updated on flash" for simplicity).

---

## R-006 — `make build-image` rebuild story (FR-004)

**Decision**: Add a `REBUILD=1` make variable to `build-image`. When set, the target invokes `nix build` with `--rebuild`, which forces all derivations to be re-realized rather than fetched from cache. Default behavior (no `REBUILD` flag) uses the cache as today — fast for unchanged inputs, but FR-004 also requires that "default behavior MUST never produce a stale image." We satisfy that by gating the SD image derivation on the SD-bootstrap module's source path: any change to the bootstrap source invalidates the derivation hash and forces a real rebuild even without `--rebuild`. Operators reach for `REBUILD=1` only when they suspect a binary-cache poisoning issue or want to verify a clean build.

**Rationale**:

- Nix's content-addressing already invalidates the SD image derivation when its inputs change. The post-mortem's "stale image" symptom was caused by something else: `make build-image` was wired to a target whose inputs did not actually include the per-host changes the operator was making. The fix is twofold: (a) ensure the SD image's derivation closure correctly depends on the SD bootstrap source, and (b) provide an explicit `REBUILD=1` escape hatch for paranoia.
- A blanket `--rebuild` default would burn build minutes on every invocation; that is a footgun in its own right.

**Alternatives considered**:

- `--rebuild` always: rejected for cost / build time on routine invocations.
- Hash-stamp the build output and compare against the source tree on every flash: over-engineering; the Nix derivation system already does this.

**Open follow-ups**:

- During Phase 2 (SD bootstrap rebuild), audit the sdImage derivation's input closure to confirm bootstrap-module changes propagate correctly; this is the actual fix for the post-mortem's stale-image bug, not the `REBUILD=1` flag.

---

## R-007 — `nixos-anywhere` invocation pattern from gibson

**Decision** *(updated 2026-05-04; original decision below)*: `make provision HOST=<host> IP=<ip>` connects as `bob@<ip>` — not `root@<ip>`. The SD bootstrap image has no root SSH login; `bob` has passwordless sudo, which is sufficient for `nixos-anywhere` (confirmed 2026-05-05, FR-012). Invocation: `nixos-anywhere --flake .#<host> --target-host bob@<ip> --disko-mode disko --phases disko,install,reboot` (W-010: `--phases` skips kexec, which fails on Pi vendor kernel 6.12.x).

**Original decision** *(superseded)*: Target was `root@<ip>` using the SD bootstrap image's root authorized key. Superseded because the SD bootstrap image (FR-020) intentionally has no root SSH login; `bob` with passwordless sudo is the correct privilege-escalation path for nixos-anywhere on these nodes.

**Rationale**:

- nixos-anywhere's `--disko-mode disko` flag delegates partitioning to the per-host disko schema (`disko/rpi4.nix` or `disko/rpi5.nix`), which is exactly the FR-010..FR-014 contract.
- `bob` with passwordless sudo satisfies nixos-anywhere's root requirement without exposing a root SSH login surface (Constitution Principle I, FR-020).
- Wrapping in a Makefile target (Principle VII) is required for any agent-driven invocation; ad-hoc CLI calls are permitted only during interactive triage.

**Alternatives considered**:

- Run `nixos-anywhere` directly on the Pi via `git clone` + local invoke: rejected as primary path — Pi RAM and disk are tight, and the gibson-driven path is faster and more cache-friendly. Local invoke remains a documented fallback (FR-012).
- Use `nixos-rebuild --target-host` instead of `nixos-anywhere`: rejected for first install — `--target-host` requires NixOS already on the disk; the SD bootstrap image is too small to host the full per-host config. Once provisioned, `--target-host` is the canonical update path (`make update-node`).

**Open follow-ups**:

- ~~Confirm nixos-anywhere can drive a disko schema that targets devices identified by `/dev/disk/by-id/...`~~ — resolved: by-path used instead (FR-010a); confirmed working on hlc-501 and hlc-504 (2026-05-04).

---

## R-008 — Module layering: how `cluster/common.nix` differs from `cluster/hlc/`

**Decision**: `modules/cluster/common.nix` contains anything that is true for *any* k3s-aimed cluster of Pis: the toolbox import, k3s OS-level prereqs, base sshd posture (key-only after FR-020 lands), bash baseline, MOTD module wiring with a parameterized banner. `modules/cluster/hlc/` overrides the banner, supplies the HLC operator user (`bob`), HLC-specific network configuration (DNS pointers to PiHole, FQDN convention `*.marks.dev`), and any HLC-only package additions. A future `modules/cluster/ecto/` would override the same handful of options without having to touch `cluster/common.nix`.

**Rationale**:

- This is the spec's three-scope layering (FR-005) made concrete. The split is by override surface: anything a future cluster *might* want to change goes into the HLC layer; anything that's "what k3s on a Pi needs" stays in common.
- Keeping `common.nix` small and option-driven (rather than service-driven) means the HLC layer is mostly setting NixOS options, not redefining services.
- The post-mortem's structural-readiness-only stance for ecto-1 (Out of Scope) is satisfied: `common.nix` is reusable today, and `cluster/ecto/` is not required to exist as a directory until ecto-1 is actually built.

**Alternatives considered**:

- Two layers (cluster + host): rejected — collapses HLC-specific and generic-cluster concerns, making future ecto-1 reuse impossible without refactor.
- Four layers (common / k8s / hlc / host): rejected — over-engineering for a single cluster; deferred until a second cluster actually exists.

**Open follow-ups**:

- During Phase 3, confirm that `modules/cluster/hlc/hosts.nix` (already on disk) reduces to the hostname/FQDN map plus the operator user, with everything else moved into `common.nix`.

---

## R-009 — Home-manager modular split (FR-019)

**Decision**: Three home-manager module files: `modules/home/base.nix` (cross-cutting defaults: neovim baseline, git, bash dotfiles, shared aliases), `modules/home/server.nix` (server-only additions: tmux config tuned for headless work, kubectl/k9s aliases), and `modules/home/workstation.nix` (workstation-only: i3, polybar, dunst, ui.nix, vscode.nix, browser config). Per-user entry points (`home/bob.nix`, `home/eaglerock.nix`) compose these: bob imports base + server; eaglerock imports base + workstation. The existing `modules/home/{i3,polybar,dunst,ui,vscode}.nix` files are pulled in by `workstation.nix` and not directly by user entry points.

**Rationale**:

- This is the spec's "shared defaults between server users and workstation users, but workstation-only modules stay workstation-only" (FR-019) realized.
- Composing at the user-entry-point level (rather than via host-level conditionals) keeps each user's configuration easy to read top-down.
- Existing per-tool modules (i3, polybar, etc.) don't need to change; only their entry points do.

**Alternatives considered**:

- Conditional imports inside per-tool modules (e.g. `if isServer then ... else ...`): rejected — conditional logic in module files makes them hard to reason about; the entry-point composition is clearer.
- Single `home/<user>.nix` file per user with no shared base: rejected — defeats the spec's shared-defaults intent.

**Open follow-ups**:

- Audit existing `home/eaglerock.nix` to make sure it doesn't accidentally pull workstation-only state into the wrong user; refactor when the split lands.

---

## R-010 — SD bootstrap minimal package set

**Decision**: The SD bootstrap (`modules/sd/bootstrap.nix` + `modules/sd/recovery-utils.nix`) installs:

- **Recovery utilities** (`modules/sd/recovery-utils.nix`), alphabetical order: `curl`, `dmidecode`, `dnsutils`, `e2fsprogs`, `git`, `gptfdisk`, `htop`, `iproute2`, `lsblk` (from `util-linux`), `mdadm`, `parted`, `pciutils`, `tmux`, `usbutils`, `vim` (basic editor), `xfsprogs`.
- **Bootstrap config** (`modules/sd/bootstrap.nix`): `bob` user with operator's authorized SSH key, sshd with key-only (PasswordAuthentication false at this layer; the W-003 deferral applies to the per-host config, not the bootstrap), DHCP on the cluster VLAN, hostname placeholder (gets overwritten by per-host config after provisioning), no per-cluster service modules.

**Rationale**:

- Recovery utilities are exactly the set the operator would reach for if a USB array degrades or a node fails to reboot: see what's plugged in, see what state filesystems are in, edit a config, push or pull from the repo if needed.
- Strictly key-only on the bootstrap image is safe and reduces the attack surface during the brief SD-only window before provisioning (and during recovery boots later). W-003 applies only to the per-host steady-state, not to the bootstrap.
- No per-cluster service modules in the bootstrap — this is what FR-003 mandates and what failed in the prior attempt.

**Alternatives considered**:

- Include the full toolbox in the bootstrap: rejected — drift from FR-003; bootstrap is not the operator's daily environment.
- Include nothing beyond ssh + DHCP: rejected — operators recovering from a degraded array need real tools on hand, not "ssh in and `nix-env -iA`."
- Different package set per Pi family: rejected — recovery doesn't depend on the Pi family.

**Open follow-ups**:

- During Phase 2 implementation, confirm the package set fits the SD card image size constraints (current sdImage builds well under 4 GB; the recovery set is small and shouldn't push past that).

---

## R-011 — `config.txt` for headless RPi servers

**Decision**: Each cluster node sets a headless-server `config.txt` profile via the nvmd module's `raspberry-pi-nix.config-txt` (or equivalent — exact option name confirmed during Phase 1 against the nvmd README). The profile applies a curated, conservative set of settings appropriate for a headless server in a rack:

- `gpu_mem=16` — minimum GPU memory split; we are not running a desktop, so any RAM given to the VideoCore is wasted.
- `dtparam=audio=off` — disable on-board audio. No use case in the cluster; off saves a small amount of memory and removes an unused driver from the kernel surface.
- `dtoverlay=disable-bt` — disable on-board Bluetooth. Not used in the cluster; freeing the UART makes the primary serial port available for headless console debug if ever needed (paired with `enable_uart=1` only when actively debugging).
- `disable_splash=1` — skip the rainbow boot splash; meaningless on headless boxes.
- `boot_delay=0` — don't sit at the firmware splash longer than necessary.
- `dtparam=nvme` — Pi 5 only; ensures the M.2 HAT's PCIe lane is initialized in the firmware before the kernel takes over (required for `/srv/ssd`).
- `enable_uart=1` — left disabled by default; flipped on per-host only when the operator is troubleshooting a non-booting node via the GPIO serial console.

**Rationale**:

- These are the settings every headless RPi server tutorial converges on, irrespective of distribution. They are conservative (no overclock, no risky tweaks), they reduce the running surface to what cluster workloads actually use, and they match the hardware reality (no display, no speaker, ethernet primary, NVMe on Pi 5).
- Keeping `config.txt` declarative through the NixOS module surface means we don't hand-edit the FAT partition; per-host overrides are option settings, not file edits.
- The Pi 5 NVMe overlay (`dtparam=nvme`) must be present at firmware time, not added at boot — easy to miss, important to record here.

**Alternatives considered**:

- Carry `main`'s implicit `config.txt` (whatever `nix-community/raspberry-pi-nix` ships): rejected — implicit defaults are exactly what failed in the prior incident; we want explicit config.
- Enable `enable_uart=1` everywhere: rejected — uart-on without active monitoring just exposes a serial console; flip only when debugging.
- Disable WiFi via `dtoverlay=disable-wifi`: deferred — not strictly necessary, and an emergency console-fallback path through WiFi is occasionally useful. Reconsider if any node shows surprising WiFi activity.

**Open follow-ups**:

- Confirm the exact NixOS option path in the nvmd fork. The previous upstream used `raspberry-pi-nix.config = { ... }`. nvmd's option name verified during Phase 1.
- Confirm `dtparam=nvme` is not already implied by nvmd's RPi 5 module; if so, dropping the explicit setting is fine.

---

## R-012 — Thermal and overclock policy per Pi family

**Decision**: Match the user's installed cooling.

- **RPi 4 (`hlc-401..404`)**: passive heatsink only. Apply a modest overclock — `over_voltage=2`, `arm_freq=1750` — well below the 2.0 GHz stretch goals that need active cooling. Heatsink keeps thermals in check; passive cooling makes a fan-failure scenario impossible. Stock 1.5 GHz remains the fallback if a node shows thermal throttling.
- **RPi 5 (`hlc-501..508`)**: official Active Cooler (heatsink + fan). Stock clocks (2.4 GHz) — no overclock applied. Pi 5 silicon is more sensitive to overvoltage, and the cluster is not CPU-bound enough for a small overclock to be worth instability risk. The fan is software-controlled by the kernel via the standard thermal trip points; no `config.txt` fan-curve override is added unless a node demonstrates inadequate cooling.

**Rationale**:

- The post-mortem records that heatsinks are installed on Pi 4s and the official heatsink+fan on Pi 5s and that the operator wants overclocking enabled. Matching the cooling is the safe path: the Pi 4 passive heatsink can support a modest overclock; the Pi 5's active cooler is *standard equipment* (Pi 5 silicon ships configured assuming active cooling) rather than headroom for further overclock.
- "Modest overclock under passive cooling" beats "ambitious overclock under active cooling" for a 24/7 cluster: thermal margin remains, fan failure cannot brick the node, and the workload (k3s control-plane on Pi 4, Longhorn/storage on Pi 5) is not aggressively CPU-bound.

**Alternatives considered**:

- Pi 5 overclock to 2.6 GHz: documented as safe with the official cooler, but introduces a regression vector (operator must remember to revert if the fan ever fails). Rejected for now; revisit only if a workload demands it.
- Per-host overclock tuning: rejected — same cooling, same silicon family, same workload class; no reason to differ across nodes within a family.

**Open follow-ups**:

- Phase 4 task to thermally validate `hlc-401` after sustained load; if 1750 MHz with passive heatsink shows throttling, drop to stock.
- Phase 4 task to spot-check Pi 5 thermals under nvme + USB activity; only if surprised do we revisit fan-curve overrides.

---

## R-013 — Firmware EEPROM beyond `BOOT_ORDER`

**Decision**: Update both the EEPROM firmware itself and its configuration during the SD baseline boot, idempotently, via a one-shot NixOS service:

- Apply the latest stable EEPROM firmware shipped with the nvmd module (or pin a specific firmware revision per the fork's recommendation). EEPROM updates are infrequent but matter for stable USB and NVMe boot on Pi 5.
- `BOOT_ORDER = 0xf14` — USB-first, SD-fallback (R-005).
- `BOOT_UART = 1` — log firmware boot decisions over the GPIO UART (no ill effect when no console is attached; invaluable when one is).
- `WAKE_ON_GPIO = 0` — Pi 5 only; the cluster has no use case for GPIO wake.
- `POWER_OFF_ON_HALT = 1` — Pi 5 only; ensures `poweroff` actually drops power, useful in the rack.

**Rationale**:

- EEPROM revision is one of the few settings the OS cannot inspect-and-correct cleanly mid-run. Locking it during the SD baseline puts the right firmware in place before USB-RAID boot ever depends on it.
- Logging boot decisions over UART is a cheap insurance policy — if a node mysteriously won't come up, the operator plugs in the GPIO UART cable and gets the firmware's own narrative for free.
- `POWER_OFF_ON_HALT` and `WAKE_ON_GPIO` are Pi-5 conveniences that match how the rack is operated (centralized power switching, no GPIO wake source).

**Alternatives considered**:

- Leave EEPROM at whatever ships with each Pi: rejected — too much variance per box; debugging firmware-version drift is exactly the post-mortem failure pattern.
- Apply EEPROM updates manually per node: rejected for fleet sanity; declarative + one-shot service is the only scalable path.

**Open follow-ups**:

- Confirm nvmd's mechanism for declaring EEPROM config (likely a `raspberry-pi-nix.eeprom-config = { ... }` option or similar). If not available, fall back to a NixOS `systemd.services.<name>` that runs `rpi-eeprom-config --apply` on first boot, gated by a marker file in `/boot`.

---

## R-014 — Binary cache and cross-compilation prerequisites

**Decision**: All x86_64 build hosts (`gibson`, `silicon`) MUST configure the nvmd Cachix binary cache as a substituter and enable aarch64-linux binfmt emulation via qemu. Cache URL: `https://nixos-raspberrypi.cachix.org`. Public key: `nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=`.

**Rationale**:

- The nvmd flake publishes prebuilt aarch64 kernels and firmware to Cachix. Without this substituter, build hosts attempt to cross-compile the Pi kernel locally — which fails on hosts without binfmt emulation and takes 30+ minutes even with it.
- Pi 5 (`bcm2712`) kernel cache hits confirmed 2026-05-03. Pi 4 (`bcm2711`) kernel had a cache miss on the same date; binfmt/qemu fallback handled it but slowly.
- Cache hits depend on the `nixpkgs` revision in the nvmd flake's lockfile matching (or being close to) the consuming project's nixpkgs pin. On major divergence, expect cache misses.
- `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on NixOS hosts (silicon) provides qemu-user-static emulation for any aarch64 derivation not in cache. Gibson (non-NixOS nix daemon) needs equivalent qemu-binfmt configured via its host OS.

**Alternatives considered**:

- Build only on gibson with native aarch64 emulation: rejected — silicon is also a valid build host; both should work.
- Use nvmd's `nixosSystem` helper with `trustCaches = true` exclusively: considered — the helper auto-trusts the cache, but system-level substituter config is more reliable and covers all build paths (SD images, dry-runs, ad-hoc `nix build`).

**Open follow-ups**:

- Monitor Pi 4 kernel cache coverage across nvmd releases; if consistently missing, consider pushing built Pi 4 kernels to a project-owned Cachix cache.
- Configure gibson's nix daemon with the same substituter once gibson is set up for cluster builds.

---

## R-015 — Bootloader migration: `kernelboot` → `kernel`

**Decision**: Set `boot.loader.raspberry-pi.bootloader = "kernel"` in both `modules/hardware/rpi4.nix` and `modules/hardware/rpi5.nix`. The SD bootstrap images are left on the nvmd default (currently `kernelboot`).

**Rationale**:

- The nvmd project deprecated `kernelboot` in favor of `kernel` (see nvmd PR#61). The `kernel` bootloader provides real generational rollback support — each NixOS generation gets its own directory on the FIRMWARE partition with matched kernel + DTBs + overlays, eliminating the FAT32 symlink hacks of `kernelboot`.
- Key advantages: atomic installs, rescue boot by editing one `config.txt` line, lazy writes for SD longevity, and `configurationLimit` for storage control.
- Each generation costs ~53 MB on the FIRMWARE partition. `configurationLimit` should be set to 3–5 when Phase 5 wires up config.txt (T030/T031).
- SD bootstrap images don't need generational rollback — they're throwaway. Leaving them on the default avoids unnecessary divergence.

**Alternatives considered**:

- Stay on `kernelboot`: rejected — deprecated; will be removed in future nvmd versions.
- Set `kernelboot-legacy-unsupported` to silence warning: rejected — just delays the inevitable migration.

**Open follow-ups**:

- Set `configurationLimit` alongside other config.txt settings in Phase 5 (T030/T031).

---

## Cross-cutting notes

- **No NEEDS CLARIFICATION markers in the spec.** All clarification questions from `/speckit-clarify` (sessions 2026-04-29 — Q1..Q7) are resolved and reflected in FR-009, FR-017, SC-002, and User Story 5 acceptance scenario 2.
- **specs/WORKAROUNDS.md** contains W-001, W-002, W-003 — all open, all with documented exit conditions. This plan intentionally does not introduce new workarounds; if an unexpected one surfaces during `/speckit-tasks` or implementation, it gets a ledger entry and a target-phase tag, per Constitution Principle V.
- **Constitution Principle VIII applies to operator interaction during the rollout**: any apparent disagreement between operator-reported state and the agent's model must be raised explicitly. The mountain-glyph terminal-rendering question (R-002) is a textbook example: the operator picked the glyph; the agent flagged the rendering risk; the agent now records a documented presentation strategy rather than silently swapping the glyph for a "safer" one.
