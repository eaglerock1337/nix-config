# Implementation Plan: NixOS RPi Cluster Foundation (v2)

**Branch**: `001-nixos-rpi-cluster` | **Date**: 2026-04-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-nixos-rpi-cluster/spec.md`

## Summary

Bring 9 Raspberry Pis (`hlc-401` on Pi 4; `hlc-501..508` on Pi 5) onto NixOS using the `nvmd/nixos-raspberrypi` fork, with a three-scope layered module structure, full-disk provisioning via `nixos-anywhere`/`disko`, operator shell UX (MOTD, PS1, toolbox, home-manager), and k3s OS-level prerequisites installed. Cluster bootstrap is out of scope. The implementation is sequenced as 8 phases (Phase 1–8, matching tasks.md numbering), each gated by `make smoke-test` on a canary node before any fleet roll.

**Status**: Phases 1–4 complete. Phases 5–8 pending.

---

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable). Target platform: aarch64-linux (RPi 4 `bcm2711`, RPi 5 `bcm2712`). Build host: `gibson` (x86_64 NixOS, cross-compiles aarch64 images).
**Primary Dependencies**:

- `github:nvmd/nixos-raspberrypi` (Pi hardware modules; confirmed working as of operator test 2026-04-30). Binary cache: `nixos-raspberrypi.cachix.org` (key: `nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=`). Build hosts MUST have this substituter configured and `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` enabled for qemu fallback on cache misses.
- `github:nix-community/disko` (declarative disk layout for provisioning)
- `github:nix-community/nixos-anywhere` (remote install onto target hardware)
- `github:nix-community/home-manager` (user environment, integrated into NixOS)
- `github:NixOS/nixos-hardware` (generic Pi modules layered under nvmd)

**Storage**: Per-node disko schema; mdadm RAID1 (`/`, full array ~28.6 GiB) + NVMe xfs (`/srv/ssd`, Pi 5 only) + SD vfat (`/boot`).

**Testing**: No unit tests — NixOS config repo. Verification model: `make dry-run` → `make build` → `make update-node` (canary node) → `make smoke-test` → fleet roll (Constitution §"Safety & Change Management"). Smoke-test definition: remove SSH host keys from `~/.ssh/known_hosts` for both IP and hostname, ping IP for reachability (`ping -c 1 -W 3`), then non-PTY SSH to hostname (`uname -a`); no `-t` flag (PTY mode caused Pi login hangs in testing).

**Target Platform**: aarch64-linux NixOS 25.11 on RPi 4 (`bcm2711`) and RPi 5 (`bcm2712`); cross-compiled / cross-built on `gibson` or `silicon` (x86_64).

**Project Type**: NixOS flake-based system configuration repository.

**Performance Goals**: SC-001 — blank SD card to SSH-reachable in ≤30 minutes operator wall-clock (excluding raw flash time).

**Constraints**: 2-space Nix indentation; alphabetical package lists; unfree on allowlist only; no monolithic catch-all configs. All agent/script invocations via Makefile targets (Constitution VII).

**Scale/Scope**: 12 host configs evaluable (`hlc-401..404`, `hlc-501..508`); 9 physically provisioned in this spec.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-evaluated after Phase 1 design.*

| Principle | Status | Notes |
| --------- | ------ | ----- |
| I. Declarative Configuration | **Pass** | All state expressed as Nix. `config.txt` and EEPROM config set via NixOS module surface. Disko schema declares disk layout. No manual FAT edits. |
| II. Reproducibility via Flakes | **Pass** | All deps locked in `flake.lock`. Pinned to specific commits. `nix flake update` is the documented advance path. |
| III. Modular Design | **Partial (W-001 active)** | During baseline-establishment (Phase 1), small inline configs may be duplicated across host files to minimize blast radius (Constitution III phased-deferral clause). W-001 logged in `specs/WORKAROUNDS.md`. Removed in Phase 6 when modules are reintroduced with canary validation. Non-negotiable from refinement onward. |
| IV. Safety-First Changes | **Pass** | Every cluster-touching change: `make dry-run` → `make build` → `make update-node` (canary on `hlc-501`) → `make smoke-test` → fleet roll. Canary scope = change set (single module or phase bundle per Constitution v1.3.3 §IV). Bundle smoke-test failure triggers bisect via `/speckit-debug`. SD reflash, on-node rebuild, and remote `--target-host` all gated. No skipping dry-run. |
| V. Pragmatic Phasing | **Pass** | W-001 (inline host configs), W-002 (passwordless wheel), W-003 (PasswordAuthentication deferred) all logged with exit conditions and target phases. W-004 (`pam_systemd` disabled in bootstrap) resolved as no-op — permanent bootstrap-scoped config decision; logged and closed in `specs/WORKAROUNDS.md`. |
| VI. Minimal & Explicit Footprint | **Pass** | Packages alphabetically sorted with rationale comments (FR-015). No unfree additions. YAGNI applied — only the listed Makefile targets are built. |
| VII. Standardized Build & Test Workflow | **Pass** | All targets route through Makefile. gibson uses `nix build …` (no `nixos-rebuild`); silicon uses `sudo nixos-rebuild`. Makefile targets abstract the distinction. |
| VIII. Human-AI Collaboration Protocol | **Pass** | Operator state treated as authoritative. Conflicts raised explicitly, never silently rewritten. R-002 (mountain glyph) is the reference example: operator picked the glyph; agent flagged the rendering risk; documented presentation strategy chosen. |

**Complexity violations**: none. Tracked deviations: W-001/W-002/W-003 (Constitution V phased workarounds, logged with exit conditions); W-004 (`pam_systemd` bootstrap PAM, resolved as no-op — permanent config decision, bootstrap-only, no exit condition needed).

---

## Testing

- `make dry-run HOST=<host>` — closure evaluation; gibson uses `nix build … --dry-run`, silicon uses `nixos-rebuild dry-run` (added Phase 1)
- `make build HOST=<host>` — full toplevel build (added Phase 1)
- `nixos-rebuild build-vm --flake .#<host>` — VM build for boot/kernel changes when feasible; Pi-targeted aarch64 builds may not VM-test; gate skipped for hardware modules with a documented note (no Makefile target)
- `make update-node HOST=<host>` — single-node `nixos-rebuild switch --target-host` (added Phase 6); operator manually canaries by running on one node, then `make smoke-test` to verify, then proceeding
- `make smoke-test HOST=<host>` — remove SSH host key from `~/.ssh/known_hosts` for both node IP and hostname, ping IP for reachability (`ping -c 1 -W 3`), then verify non-PTY SSH login succeeds on hostname (`uname -a`; no `-t` flag; PTY mode caused Pi login hangs during testing) (added Phase 1)
- `make rollback HOST=<host>` — single-node `nixos-rebuild --rollback --target-host` (added Phase 6)
- Automated canary (a single command that switches + smoke-tests + auto-rollbacks) is **out of scope for this spec**; the manual operator procedure above satisfies Constitution IV's canary requirement
- Acceptance via the operator runbook in `quickstart.md`

**Target Platform**: aarch64-linux NixOS 25.11 on RPi 4 (bcm2711) and RPi 5 (bcm2712); cross-compiled / cross-built on `gibson` (x86_64).
**Project Type**: NixOS flake-based system configuration repository.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-nixos-rpi-cluster/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Pre-spec — technical decisions and rationale
├── data-model.md        # Phase 1 — entities, attributes, relationships
├── quickstart.md        # Phase 1 — operator runbook (phase-by-phase)
├── contracts/
│   └── makefile-targets.md  # Contract: all Makefile targets
└── tasks.md             # Phase 1 output (/speckit-tasks command)
```

### Source Code

```text
flake.nix                     # Entry point: inputs, nixosConfigurations, mkHlcNode, mkHlcBootstrap,
                              #   packages.aarch64-linux (SD bootstrap images), operatorPubkey
flake.lock                    # Locked inputs (includes nvmd/nixos-raspberrypi)
Makefile                      # Operator interface (Constitution VII)
specs/WORKAROUNDS.md          # W-001/W-002/W-003 ledger (Constitution V)

hosts/
├── silicon/                  # Workstation (unchanged except toolbox wiring)
├── hlc-401/configuration.nix # Pi 4 — control-plane bootstrap node
├── hlc-402/configuration.nix # Pi 4 — deferred (config-only, never flashed)
├── hlc-403/configuration.nix # Pi 4 — deferred (config-only, never flashed)
├── hlc-404/configuration.nix # Pi 4 — deferred (config-only, never flashed)
├── hlc-501/configuration.nix # Pi 5 — canary node
├── hlc-502/configuration.nix
├── hlc-503/configuration.nix
├── hlc-504/configuration.nix
├── hlc-505/configuration.nix
├── hlc-506/configuration.nix
├── hlc-507/configuration.nix
└── hlc-508/configuration.nix

modules/
├── cluster/
│   ├── common.nix            # Generic-cluster scope: toolbox, k3s prereqs, sshd, bash, MOTD wiring
│   └── hlc/
│       ├── default.nix       # HLC cluster scope: operator user, HLC FQDN convention, HLC banner
│       └── hosts.nix         # HLC host-to-IP/MAC map
├── hardware/
│   ├── rpi4.nix              # RPi 4 hardware module (config.txt, thermal, EEPROM)
│   ├── rpi5.nix              # RPi 5 hardware module (config.txt, NVMe, thermal, EEPROM)
│   ├── rpi-eeprom.nix        # One-shot EEPROM update service (FR-026)
│   └── x1-carbon.nix         # Workstation hardware (unchanged)
├── home/
│   ├── base.nix              # Cross-cutting: neovim, git, bash dotfiles, shared aliases
│   ├── server.nix            # Server-only: tmux config, kubectl/k9s aliases
│   ├── workstation.nix       # Workstation-only: imports i3, polybar, dunst, vscode, ui modules
│   ├── colors.nix            # Gruvbox color values (unchanged)
│   ├── i3.nix                # (unchanged; imported by workstation.nix)
│   ├── polybar.nix           # (unchanged; imported by workstation.nix)
│   └── ...                   # Other existing home modules
├── motd/
│   └── default.nix           # Parameterized MOTD module (FR-018)
├── sd/
│   ├── bootstrap.nix         # SD bootstrap config: bob + key + DHCP + minimal recovery
│   └── recovery-utils.nix    # Recovery utility package set (FR-002)
├── shell/
│   ├── common.nix            # Bash canonical shell, baseline aliases
│   ├── prompt.nix            # Two-form PS1 (local Gruvbox + remote xterm-safe; R-002)
│   └── utilities.nix         # Sysadmin toolbox (FR-015): alphabetical packages + comments
├── hosts/                    # Silicon host modules (unchanged)
│   └── ...
└── k8s/
    └── prereqs.nix           # k3s enabled-but-stopped, container deps, kernel/sysctl, k9s

disko/
├── rpi4.nix                  # Disko schema: Pi 4 (SD /boot + USB RAID1 single partition for /)
└── rpi5.nix                  # Disko schema: Pi 5 (adds NVMe /srv/ssd)

home/
├── eaglerock.nix             # Composes: base + workstation
└── bob.nix                   # Composes: base + server

scripts/
└── smoke-test.sh             # Kept from main; superceded by Makefile smoke-test target
```

**Structure Decision**: Layered NixOS flake. Three module scopes (`modules/cluster/common.nix` → `modules/cluster/hlc/` → `modules/hardware/rpi{4,5}.nix`) plus per-host files (`hosts/<hostname>/`). Operator-environment modules (toolbox, shell, MOTD, home-manager) are cross-cutting: imported by `modules/cluster/common.nix` and apply to all cluster hosts. Workstation modules (i3, polybar) remain workstation-only, imported only by `home/eaglerock.nix` via `modules/home/workstation.nix`.

---

## Complexity Tracking

No Constitution violations to justify. W-001/W-002/W-003 are all Constitution V phased workarounds with logged exit conditions — they are compliant deviations, not violations.

---

## Phasing Notes (W-001 alignment)

The implementation is sequenced to satisfy the W-001 "re-introduce modules with canary gate" exit condition while keeping each phase's blast radius small. Phase order is determined by dependency (you can't provision before you have an SD baseline; you can't apply UX modules before nodes are provisioned).

| Phase | Spec Stories | FR refs | Gate |
| ----- | ----------- | ------- | ---- |
| 1 Setup | Pre-req + US1 upstream swap | — / FR-001 | hlc-501 smoke-test green ✅ confirmed |
| 2 Foundational | (subsumed by Phase 1) | — | — |
| 3 US1 | US1 SD bootstrap | FR-002..004 | Bootstrap SD boots, cache invariant verified |
| 4 US2 | US2 | FR-005..009 | All 12 hosts dry-run from clean checkout |
| 5 US3 | US3 | FR-010..014 | 9 nodes provisioned, recovery scenario verified |
| 6 US4 | US4 | FR-015..020 | SC-006 verified; W-001 + W-003 closed |
| 7 US5 | US5 | FR-021..023 | SC-007 verified; no cluster state on disk |
| 8 Polish | — | all | All SCs validated; spec closed out |

**Phase-bundle cadence for Phase 6 (US4)**: Per Constitution v1.3.3 §IV, the canary scope is the change set. Phase 6 deploys all US4 modules as a bundle via `/speckit-implement`, then a single canary on `hlc-501`. Smoke-test green → fleet roll. Smoke-test fail → `make rollback HOST=hlc-501` → `/speckit-debug` bisect (comment-out new module imports in `modules/cluster/common.nix` one at a time, redeploy, smoke-test) → isolate breaking module → fix → resume. All other phases are naturally single-module or single-concern per deploy.

---

## Phase 1 — Setup ✅ CONFIRMED COMPLETE

**Covers**: former plan.md Phase 0 (baseline reset) + former Phase 1 (upstream swap). Corresponds to tasks.md Phase 1 Setup (T001–T008).

**Status**: Complete.

**Goal**: Running code (`flake.*`, `hosts/silicon`, `hosts/hlc-501`, `home/eaglerock.nix`, existing `modules/home`, `modules/hosts`, `modules/hardware/x1-carbon.nix`) at `main`'s working state. All spec/plan/research/context artifacts preserved.

**Keep**: spec-kit artifacts, Claude context, `specs/WORKAROUNDS.md`, existing Makefile build-out, `scripts/smoke-test.sh`.
**Delete**: Failed-attempt-only files — prior Pi 4 host configs, `hlc-502..508` host stubs from prior attempt, `modules/{cluster,motd,shell,users}` from prior attempt, `modules/hardware/rpi{4,5}.nix` from prior attempt, debug artifacts (`hlc-output.txt`, `lshw-output.txt`), stale `tasks.md`.

```bash
git tag pre-reset-2026-04-29

# Restore main's running code
git checkout main -- \
    flake.nix flake.lock Makefile \
    hosts/silicon hosts/hlc-501 \
    home/eaglerock.nix \
    modules/home modules/hosts modules/hardware/x1-carbon.nix

# Delete failed-attempt-only files
git rm -r \
    hosts/hlc-401 hosts/hlc-402 hosts/hlc-403 hosts/hlc-404 \
    hosts/hlc-502 hosts/hlc-503 hosts/hlc-504 hosts/hlc-505 \
    hosts/hlc-506 hosts/hlc-507 hosts/hlc-508 \
    modules/cluster modules/motd modules/shell modules/users \
    modules/hardware/rpi4.nix modules/hardware/rpi5.nix
git rm -f hlc-output.txt lshw-output.txt

git commit -m "Phase 0: baseline reset — running code to main, context kept"
git tag phase0-baseline-reset
```

**Validation gate** — all four MUST pass before tagging `phase0-baseline-reset`:

1. `make silicon-dry` — silicon's NixOS config evaluates clean (target exists on `main`).
2. `make build-image HOST=hlc-501` — Pi 5 SD image builds. Still on `raspberry-pi-nix` here; nvmd swap is Phase 1. (No `build-image-rpi5` alias on `main`; the parameterized form is canonical.)
3. `make flash-image HOST=hlc-501 DEV=/dev/sdX` — image flashes.
4. Insert SD into `hlc-501`, power on. Remove known_hosts entries for `10.23.50.51` and `hlc-501`, then `ssh bob@10.23.50.51 uname -a` and `ssh bob@hlc-501 uname -a` — both MUST succeed. No PTY (`-t` flag) — PTY mode caused Pi login hangs during testing. (`make smoke-test` was added in Phase 1; this manual SSH check was the gate before it existed.)

If any step fails, the reset is incomplete. Diagnose and re-run until green. Do **not** proceed to Phase 1 with a yellow gate — Constitution VIII applies (operator-observed state is authoritative, do not silently assume around it).

---

### Upstream Swap ✅ CONFIRMED WORKING

**Status**: Operator confirmed 2026-04-30. `nvmd/nixos-raspberrypi` is in place, `hlc-501` boots and accepts SSH. Tag `phase1-nvmd-swap` if not already set.

**What was done**:

- `flake.nix`: Removed `raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix"`. Added `nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi"`. Re-added `operatorPubkey` + `mkHlcNode` helper. Added `disko`, `nixos-anywhere`, `sops-nix` inputs.
- `nix flake update` — re-locked; committed `flake.nix` + `flake.lock`.
- Phase 1 Makefile targets added: `dry-run`, `build`, `smoke-test`, `ip`.
- `hlc-501` boots on nvmd fork, accepts SSH as `bob`.

**Smoke-test reminder**: `make smoke-test HOST=hlc-501` runs the updated definition — removes known_hosts entries for IP + hostname, then non-PTY SSH to both. No `-t` flag.

**Phase exit gate**: ✅ `hlc-501` boots on nvmd fork, smoke-test green. Tag: `phase1-nvmd-swap`.

---

## Phase 3 — SD Bootstrap Rebuild (US1)

**Spec**: US1 | **FR**: FR-002..FR-004 | **Research**: R-006, R-010

**Goal**: SD bootstrap config is barebones (bob + key + recovery utils + DHCP) and physically separated from per-host service modules. Stale-image bug (post-mortem root cause) closed by ensuring the sdImage derivation closure correctly depends on `modules/sd/bootstrap.nix`.

1. Create `modules/sd/bootstrap.nix` (bob user, operator key, DHCP on HLC VLAN, key-only sshd, hostname placeholder) and `modules/sd/recovery-utils.nix` (alphabetical recovery package set per R-010: `curl`, `dmidecode`, `dnsutils`, `e2fsprogs`, `git`, `gptfdisk`, `htop`, `iproute2`, `lsblk`, `mdadm`, `parted`, `pciutils`, `tmux`, `usbutils`, `vim`, `xfsprogs`).
2. Add `mkHlcBootstrap` helper and `packages.aarch64-linux` block to `flake.nix`. Each SD image is a separate derivation: Pi base module + `sd-image` + `modules/sd/bootstrap.nix` + hostname. The SD image derivation is completely independent of `nixosConfigurations` — per-host service modules, cluster scope, hardware scope, and k8s scope cannot appear in the bootstrap closure. `make build-image HOST=<host>` builds `.#packages.aarch64-linux.<host>-sdImage`.
3. Add `REBUILD=1` opt-in to `make build-image` (passes `--rebuild` to `nix build`).
4. Audit the sdImage derivation's input closure: change a comment in `modules/sd/bootstrap.nix`, run `make build-image HOST=hlc-501` (no `REBUILD`), confirm the output hash differs — this validates FR-004 / the post-mortem stale-image fix.
5. Flash rebuilt SD on `hlc-501`; `make smoke-test HOST=hlc-501` after boot.

**Phase exit gate**: SD boots, smoke-test green, cache invariant verified. Tag `phase3-sd-bootstrap`.

---

## Phase 4 — Per-Host Scaffolding (US2)

**Spec**: US2 | **FR**: FR-005..FR-009 | **Research**: R-008

**Goal**: All 12 host configurations (`hlc-401..404`, `hlc-501..508`) evaluate via `make dry-run` from a clean checkout. Module layering is in place.

1. Stand up `modules/cluster/common.nix` skeleton — structural skeleton only: shell baseline stub, toolbox import stub, MOTD wiring stub, sshd posture stub. (Service-level modules added in later phases; this is structure, not implementation.)
2. Stand up `modules/cluster/hlc/default.nix` consuming `cluster/common.nix`; HLC-specific options (operator user stub, MOTD banner reference, FQDN convention `*.marks.dev`) override here.
3. Create all 12 per-host files: `hosts/hlc-{401..404,501..508}/configuration.nix`. Per-host file contains only hostname, family, IP/MAC. Import chain: per-host → `modules/cluster/hlc/default.nix` → `modules/cluster/common.nix` → hardware. Deferred Pi 4 hosts (`hlc-402..404`) have config but MUST NOT be flashed.
4. Hardware stubs: `modules/hardware/rpi4.nix` and `modules/hardware/rpi5.nix` (minimal at this phase; config.txt and EEPROM added in Phase 5).
5. `make dry-run HOST=hlc-401`, `make dry-run HOST=hlc-501`, ... `make dry-run HOST=hlc-508`, `make dry-run HOST=hlc-402`, `make dry-run HOST=hlc-403`, `make dry-run HOST=hlc-404` — all 12 MUST succeed.
6. SC-003 testability: confirm adding a stub `hosts/hlc-509/configuration.nix` + flake entry requires no other edits.

**Phase exit gate**: SC-002 + SC-003 satisfied. All 12 evaluate. Tag `phase4-scaffolding`.

---

## Phase 4.5 — `/speckit-debug` Skill (FR-028) *(retroactive: added 2026-05-01)*

**Spec**: FR-028 | **Task**: T027a

**Goal**: Create the `/speckit-debug` Claude Code skill file before Phase 6 bundle-canary. This is a pure tooling deliverable — no NixOS config change, no canary required.

1. Create `.claude/skills/speckit-debug/skill.md` per FR-028 rules: operator-initiated; network-only/SSH from gibson; operator-trust model; conversational format; reads constitution + post-mortem at invocation; spec/plan on demand; degraded-mode warning if context files are unreadable.

**Phase exit gate**: `/speckit-debug` skill file exists and is invocable. T027a complete.

---

## Phase 5 — Disko + nixos-anywhere Provisioning (US3)

**Spec**: US3 | **FR**: FR-010..FR-014 | **Research**: R-004, R-005, R-007

**Goal**: Provisioning workflow installs full per-host NixOS onto USB-RAID + NVMe. Boot order locked to USB-first, SD-fallback.

1. Create `disko/rpi4.nix` and `disko/rpi5.nix` per R-004:
   - Both: `/boot` on SD vfat, `/` on 2-disk mdadm RAID1 (ext4, full array; drives are ~30 GB / ~28.6 GiB usable — single partition, no `/srv/usb`).
   - Pi 5 only: `/srv/ssd` on NVMe (xfs).
   - Use `/dev/disk/by-path/` paths (not `by-id/`) per FR-010a. Convention: a-drive = left port = `platform-xhci-hcd.0-usb-0:1:1.0-scsi-0:0:0:0`, b-drive = right port = `platform-xhci-hcd.1-usb-0:1:1.0-scsi-0:0:0:0`. This pattern is consistent across all Pi 5 nodes. Pre-provision check: both drives MUST show a `usbv3` alias in `/dev/disk/by-path/`; re-seat any that show `usbv2`. Paths exposed via `config.hlc.disko.{usbDevice0,usbDevice1,nvmeDevice}` NixOS options.
2. Expand `modules/hardware/rpi{4,5}.nix` with `config.txt` headless profile (FR-025, R-011) and per-family thermal settings (FR-027, R-012). Note: `boot.loader.raspberry-pi.bootloader = "kernel"` already set (R-015); add `configurationLimit` (3–5 generations) alongside config.txt settings.
3. Create `modules/hardware/rpi-eeprom.nix` — idempotent one-shot systemd service to apply EEPROM config (FR-026, R-013): `BOOT_ORDER=0xf14`, `BOOT_UART=1`, Pi 5 extras (`WAKE_ON_GPIO=0`, `POWER_OFF_ON_HALT=1`). Gated by a marker file to prevent re-run.
4. Add `make provision HOST=<host>` target (per contracts/makefile-targets.md §"Added Phase 5 US3").
5. Provision `hlc-501`: `make provision HOST=hlc-501`. Confirm reboots into USB array root, `/srv/ssd` on NVMe. `make smoke-test HOST=hlc-501` green.
6. Recovery test (FR-011, SC-005): power down `hlc-501`, detach USB drives, power on. SD recovery boots; `make smoke-test HOST=hlc-501` green; SSH in, run `mdadm --examine`. Re-attach USB drives, normal boot resumes.
7. Provision remaining work-set serially: `make provision HOST=hlc-502` … `hlc-508`, then `hlc-401`. `make smoke-test HOST=<host>` after each. (No automation wrapper — operator manual loop.)
8. `hlc-401` provisioning validates Pi 4 path: `/srv/ssd` absent without error.

**Phase exit gate**: All 9 work-set nodes provisioned. SC-005 verified for at least one Pi 5 and `hlc-401`. Tag `phase5-provisioned`.

---

## Phase 6 — Operator UX (US4)

**Spec**: US4 | **FR**: FR-015..FR-020 | **Research**: R-002, R-009

**Goal**: HLC MOTD, two-form PS1 (local Gruvbox + remote xterm-safe), sysadmin toolbox, modular home-manager, SSH hardening — all in place. W-001 + W-003 closed.

**Phase-bundle cadence**: `/speckit-implement` runs all module-creation tasks (steps 1–7 below) as one batch, then a single canary on `hlc-501` (step 8). On smoke-test green → serial fleet roll (step 9). On smoke-test fail → rollback → `/speckit-debug` bisect.

At the start of this phase, add Makefile targets:

- `make update-node HOST=<host> [IP=<ip>]` — wraps `sudo nixos-rebuild switch --flake .#<host> --target-host bob@<IP> --use-remote-sudo`.
- `make rollback HOST=<host> [IP=<ip>]` — wraps `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<IP> --use-remote-sudo`.

Module reintroduction order (W-001 exit):

1. **Toolbox** (`modules/shell/utilities.nix`) — alphabetical packages with inline rationale. Land first; every later module imports it.
2. **Bash baseline** (`modules/shell/common.nix`) — canonical shell, baseline aliases.
3. **PS1** (`modules/shell/prompt.nix`) — local form: silicon-style, Gruvbox colors, `////` → `☁⛰☁`. Remote form: two-line box-drawing (`┌─╸user@fqdn ☁⛰☁ [cwd]` / `└──╸$`), no color codes, FQDN. Mountain glyph: `⛰︎` (U+26F0 + U+FE0E text-presentation selector); `hlc.prompt.mountainGlyph` option for ASCII fallback (R-002). Validate rendering on kitty + `xterm-256color` SSH + `TERM=xterm` SSH.
4. **MOTD** (`modules/motd/default.nix`) — parameterized banner module (FR-018). HLC banner matches post-mortem reference exactly; `hostnameFormat = "Cluster node: <fqdn>"` interpolated from `config.networking.fqdn`; Bob Ross quote static.
5. **Operator user** (`modules/users/operator.nix`) — `bob` with hardcoded authorized key (W-002 site annotated), passwordless wheel (W-002), key-only sshd planned but deferred to sub-step 7 (W-003).
6. **Home-manager modular split** — `modules/home/{base,server,workstation}.nix` per R-009. `home/bob.nix` composes base + server; `home/eaglerock.nix` composes base + workstation. Apply to silicon via `make silicon-switch`; apply to cluster per canary pattern.
7. **SSH hardening** — `services.openssh.settings.PasswordAuthentication = false` + `KbdInteractiveAuthentication = false`. Closes W-003. Verify key-only login still works after each switch.
8. **[BUNDLE-CANARY]**: `make update-node HOST=hlc-501` → `make smoke-test HOST=hlc-501`. On fail: rollback + bisect. On green: proceed.
9. **Fleet roll** (serial): `make update-node HOST=<host>` + `make smoke-test HOST=<host>` for `hlc-502..508`, then `hlc-401`.

**Phase exit gate**: SC-006 verified (SSH as `bob` into any cluster node → styled bash + HLC MOTD + toolbox; SSH as `eaglerock@silicon` → same toolbox, no HLC MOTD). W-001 + W-003 marked Resolved. Tag `phase6-operator-ux`.

---

## Phase 7 — k3s Prerequisites (US5)

**Spec**: US5 | **FR**: FR-021..FR-023 | **Research**: R-003

**Goal**: Every in-scope node has k3s, k9s, container runtime, kernel/sysctl prereqs installed. k3s service enabled but stopped; no cluster state on disk.

1. Create `modules/k8s/prereqs.nix`:
   - `services.k3s.enable = true` (installs binary + systemd unit).
   - `systemd.services.k3s.wantedBy = lib.mkForce [ ]` (enabled but never auto-started — R-003).
   - Container runtime deps: `containerd`, `runc` (k3s bundles these but explicit is better).
   - Kernel modules: `br_netfilter`, `overlay`, `ip_tables`.
   - Sysctls: `net.ipv4.ip_forward = 1`, `net.bridge.bridge-nf-call-iptables = 1`, `net.bridge.bridge-nf-call-ip6tables = 1`, `kernel.modules_disabled = 0`.
   - cgroups v2: `systemd.enableCgroupAccounting = true`.
   - Packages: `k9s`, `kubectl` (for the `k` alias).
   - Bash alias: `k = kubectl` (in `modules/shell/common.nix` or server home-manager).
2. Import `modules/k8s/prereqs.nix` from `modules/cluster/common.nix`.
3. Apply to `hlc-501`: `make update-node HOST=hlc-501` → `make smoke-test HOST=hlc-501`. Verify `k3s --version`, `k9s --version`, `k version --client`; `systemctl is-enabled k3s` → enabled; `systemctl is-active k3s` → inactive.
4. Serial fleet roll: `make update-node HOST=<host>` + `make smoke-test HOST=<host>` for `hlc-502..508`, then `hlc-401`.

**Phase exit gate**: SC-007 verified — packages and prereqs present on all 9 work-set nodes; k3s enabled but stopped; no cluster state on disk. Tag `phase7-k3s-prereqs`.

---

## Phase 8 — Polish & Cross-Cutting Validation

**Spec**: all | **Tasks**: T092–T099

Final acceptance criteria validation and spec close-out. See tasks.md Phase 8 for the full task list. Key gates: SC-001 (≤30 min wall-clock to SSH-reachable), SC-002 (all 12 dry-run from clean checkout), SC-004 (Pi 4 + Pi 5 same workflow), SC-007 (k3s prereqs complete). Tag `phase8-complete`; open PR.

---

## Post-spec State

After all 6 phases:

- All 9 work-set nodes running NixOS on nvmd fork, USB-RAID root, per-host operator UX, k3s prereqs installed.
- All 12 host configs evaluable from clean checkout (SC-002).
- Deferred Pi 4s (`hlc-402..404`) on Debian, untouched.
- Open ledger: W-002 (passwordless wheel → secrets management feature spec). W-001, W-003, W-004 closed (W-004 resolved as no-op: bootstrap-permanent PAM fix, no removal needed). W-001 + W-003 closed by Phase 6.
- The follow-on cluster-bootstrap spec starts here: flips `wantedBy`, drops k3s config, brings up the cluster. No reflashing required.

---

## Filesystem Decisions (FR-014)

| Mount | FS | Rationale |
| ----- | -- | --------- |
| `/boot` | vfat | Pi firmware requirement |
| `/` | ext4 | Durability, journaling, well-understood RAID1 recovery; full array (~28.6 GiB) — single partition |
| `/srv/ssd` | xfs | Better for large-file / Longhorn-class workloads; deferred to future spec but xfs now avoids a reformatting step later |

---

## Research Index

All technical decisions are in [research.md](./research.md):

| ID | Decision |
| -- | -------- |
| R-001 | Upstream Pi NixOS source: `nvmd/nixos-raspberrypi` main branch ✅ confirmed working |
| R-002 | Mountain-glyph `⛰` presentation: `U+FE0E` text selector + `hlc.prompt.mountainGlyph` ASCII fallback |
| R-003 | k3s enabled-but-stopped: `services.k3s.enable = true` + `wantedBy = mkForce []` |
| R-004 | Disko schemas: two files (`rpi4.nix`, `rpi5.nix`); ext4 for RAID, xfs for NVMe; `by-path/` disk identification (USB port deterministic; `xhci-hcd.0`=left/a, `xhci-hcd.1`=right/b) |
| R-005 | Boot order: EEPROM `BOOT_ORDER = 0xf14` (USB-first, SD-fallback) |
| R-006 | `make build-image` rebuild: `REBUILD=1` opt-in + derivation closure correctness |
| R-007 | `nixos-anywhere` invocation: from gibson as `root@<ip>`, `--disko-mode disko` |
| R-008 | Module layering: `cluster/common.nix` (generic-cluster) vs `cluster/hlc/` (HLC-specific) |
| R-009 | Home-manager split: `base.nix` + `server.nix` + `workstation.nix` |
| R-010 | SD bootstrap package set: recovery utilities alphabetical list |
| R-011 | `config.txt` headless server profile: `gpu_mem=16`, audio off, BT off, no splash |
| R-012 | Thermal policy: Pi 4 passive 1750 MHz modest OC; Pi 5 stock 2.4 GHz + kernel fan curve |
| R-013 | EEPROM config: `BOOT_ORDER`, `BOOT_UART`, `POWER_OFF_ON_HALT` (Pi 5), `WAKE_ON_GPIO` (Pi 5) |
| R-014 | Binary cache: `nixos-raspberrypi.cachix.org` substituter + binfmt emulation on build hosts |
| R-015 | Bootloader migration: `kernelboot` → `kernel` (nvmd PR#61); set in rpi4/rpi5 hardware modules |
