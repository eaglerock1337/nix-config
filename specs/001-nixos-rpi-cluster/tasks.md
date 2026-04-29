---
description: "Task list for NixOS RPi Cluster Foundation (v2)"
---

# Tasks: NixOS RPi Cluster Foundation (v2)

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)
**Constitution**: v1.3.2
**Generated**: 2026-04-29

> **Phase numbering note**: Tasks are grouped under `Phase 0..8` headers below (operational order). Git tags (`phase0-baseline-reset`, `phase1-nvmd-swap`, `phase2-sd-bootstrap`, `phase3-per-host-scaffolding`, `phase4-disko-provisioning`, `phase5-operator-ux`, `phase6-k3s-prereqs`) follow the [plan.md → "Phasing notes"](./plan.md#phasing-notes-w-001-alignment) numbering, which is offset by one from the tasks.md headers (plan's Phase 1 = tasks' Phase 2 Foundational, etc.). The two-numbering convention is intentional: tasks.md adds a Setup phase + Polish phase that the plan does not enumerate. Use the tag names below as the canonical phase markers for `git bisect`.

**Tests**: Test tasks are NOT included. This is a NixOS configuration repo; the verification model is `dry-run` → `build` → `update-node` (one host) → `smoke-test` (Constitution §"Safety & Change Management"), not unit/integration tests. Operator manually canaries by running `update-node` on the canary node, verifying with `smoke-test`, then proceeding to the rest of the work-set (or `make rollback` if smoke-test fails). **Canary scope** = the change set being deployed; per Constitution v1.3.2 §IV both per-module and phase-bundle scopes are admissible (bundle path additionally requires `/speckit-debug` on smoke-test fail to bisect to the breaking module). Automated single-command canary is out of scope for this spec.

**Organization**: Tasks are grouped by user story (US1..US5 from spec.md). Each user story phase ends in a phase-exit `git tag` so any phase boundary can be `git bisect`-ed back to.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependencies on incomplete tasks
- **[Story]**: User story label (US1..US5) — only on story-phase tasks; setup/foundational/polish phases have no story label
- File paths assume repo-root cwd: `/Users/petermarks/src/nix-config`

## Pre-condition: Phase 0 — Baseline reset (operator-managed)

Phase 0 is the operator's manual reset of the running code to `main`'s working state, executed via the `git checkout main -- … && git rm …` sequence in [plan.md](./plan.md#phase-0--baseline-reset). It MUST be complete (tagged `phase0-baseline-reset`) before T001 begins. The tasks below assume that reset has happened: `flake.nix` has only `silicon` + `hlc-501`, on `raspberry-pi-nix`, with no `sops-nix` / `disko` / `operatorPubkey` / `mkHlcNode`; the broken modules are deleted; `WORKAROUNDS.md`, the `Makefile` build-out, and this entire `specs/` directory are intact.

If `git tag --list 'phase0-baseline-reset'` is empty, stop and run Phase 0 first per `quickstart.md`. Constitution VIII applies — do not start Phase 1 against an unverified substrate.

---

## Phase 1: Setup (post-Phase-0 verification)

**Purpose**: Confirm Phase 0 landed cleanly and the working tree matches the assumptions of the rest of this list.

- [ ] T001 Verify `git tag --list 'phase0-baseline-reset'` returns the tag; if not, abort and run Phase 0 first
- [ ] T002 [P] Run `make silicon-dry`; expect exit 0
- [ ] T003 [P] Run `make build-image HOST=hlc-501`; expect exit 0 and an image artifact in `result/sd-image/`. (Main does not ship a `build-image-rpi5` alias; the parameterized form is canonical.)
- [ ] T004 [P] Run `git diff main -- flake.nix hosts/hlc-501 hosts/silicon home/eaglerock.nix modules/home modules/hosts modules/hardware/x1-carbon.nix`; expect empty diff (running code matches `main`)
- [ ] T005 Re-read [WORKAROUNDS.md](../../WORKAROUNDS.md) and confirm W-001/W-002/W-003 entries reference Phase 5 (not Phase 7) per the post-analyze update; if drift detected, fix before proceeding
- [ ] T006 Re-read [.specify/memory/constitution.md](../../.specify/memory/constitution.md) §"Cluster Topology" — confirm hlc-402..404 are decom-set (untouchable beyond dry-run)

**Checkpoint**: Branch state verified. Foundational work can begin.

---

## Phase 2: Foundational — upstream swap + flake input restoration

**Purpose**: Swap `raspberry-pi-nix` → `nvmd/nixos-raspberrypi`, re-introduce the flake-level helpers and inputs that all later phases consume. This phase blocks every user story; nothing else builds without it.

**⚠️ CRITICAL**: No user story work begins until T015 tag (`phase1-nvmd-swap`) lands.

- [ ] T007 In `flake.nix`, remove `inputs.raspberry-pi-nix.url` and add `inputs.nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi"` (verify exact input name + branch against the nvmd repo's current README during this task)
- [ ] T008 In `flake.nix`, re-add the `operatorPubkey` constant (single string literal, the operator's `eaglerock@gibson` SSH public key) — value preserved from the prior branch state's `flake.nix`
- [ ] T009 In `flake.nix`, re-add the `mkHlcNode` helper as a **thin wrapper** around `nixpkgs.lib.nixosSystem`. The helper composes: `home-manager.nixosModules.home-manager` (the user mapping `home-manager.users.bob = import ./home/bob.nix` is wired by T080, not here in Phase 2), the per-host `configuration.nix`, and a caller-supplied Pi-family argument (the `nixos-hardware.nixosModules.raspberry-pi-{4,5}` module — passed via T041 from each `nixosConfigurations.<host>` entry). **NOT in mkHlcNode**: nvmd cluster-common modules (sd-image baseline + raspberry-pi base) — those belong in `modules/cluster/common.nix` per FR-006 ("deeper modules MUST be imported from within the appropriate scope-level module"); they land in T024 alongside the rest of the cluster-common scope. **Also NOT in mkHlcNode**: Pi-family upstream modules (covered by the family arg + per-host config import of `modules/hardware/rpi{4,5}.nix`); `modules/hardware/rpi{4,5}.nix` itself carries family-specific *NixOS config* — config.txt overlays, NVMe overlay (Pi 5), thermal/overclock settings — NOT upstream module imports. For now `mkHlcNode`'s only caller is `hlc-501` (Pi 5)
- [ ] T010 [P] In `flake.nix`, add `inputs.disko.url = "github:nix-community/disko"` with `inputs.disko.inputs.nixpkgs.follows = "nixpkgs"` (used in Phase 5)
- [ ] T011 [P] In `flake.nix`, add `inputs.nixos-anywhere.url = "github:nix-community/nixos-anywhere"` pinned to a specific revision per [research.md R-007](./research.md) (used in Phase 5)
- [ ] T012 [P] In `flake.nix`, add `inputs.sops-nix.url = "github:Mic92/sops-nix"` with `inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs"` (deferred usage; W-002)
- [ ] T013 In `hosts/hlc-501/configuration.nix`, replace any `raspberry-pi-nix` module references with the equivalent nvmd module names (verify against nvmd README — typical names like `raspberry-pi-nix.nixosModules.raspberry-pi` become the nvmd-named equivalent)
- [ ] T014 Re-lock the flake input-scoped to the additions made in T007/T010/T011/T012: `nix flake update nixos-raspberrypi disko nixos-anywhere sops-nix` (input names match the `inputs.<name>` keys; do NOT run a bare `nix flake update`, which would also bump nixpkgs/home-manager/nixos-hardware on the same commit and obscure the upstream swap). Also add the four Phase 2 Foundational Makefile targets per [contracts/makefile-targets.md](./contracts/makefile-targets.md) §"Added Phase 2 Foundational": `dry-run HOST=<host>`, `build HOST=<host>`, `smoke-test HOST=<host>`, `ip HOST=<host>` (each with HOST→IP derivation per the HLC IP convention where applicable). Commit `flake.nix`, `flake.lock`, and `Makefile` together with a message describing the upstream swap and listing the locked nvmd revision and the new operator targets
- [ ] T015 Validate: `make build HOST=hlc-501` succeeds; `make build-image HOST=hlc-501` succeeds; `make flash-image HOST=hlc-501 DEV=/dev/sdX`; insert SD into `hlc-501`, power on, run `make smoke-test HOST=hlc-501` — green
- [ ] T016 On success, `git tag phase1-nvmd-swap`

**Checkpoint**: Pi 5 boots on NixOS via the nvmd fork. All user-story phases can now begin (US2..US5 in priority order; story phases are mostly independent of each other once foundational is green).

---

## Phase 3: User Story 1 — Pi 5 boots from a barebones SD baseline (Priority: P1) 🎯 MVP

**Goal**: A Raspberry Pi 5 boots NixOS from an SD image whose only contents are: `bob` user with operator's authorized key, network DHCP, recovery utilities, and the nvmd kernel/firmware. Per-host service modules are physically separated from the SD bootstrap configuration so they cannot accidentally bloat or break the recovery image (FR-002, FR-003).

**Independent Test**: Build the new SD image for `hlc-501`, flash, boot, smoke-test. Then change a comment in the bootstrap source, rebuild without `REBUILD=1`, confirm the resulting image hash differs (FR-004 cache invariant — the post-mortem's stale-image vector is closed).

### Implementation for User Story 1

- [ ] T017 [P] [US1] Create `modules/sd/recovery-utils.nix` with the alphabetical recovery package set per [research.md R-010](./research.md): `curl`, `dmidecode`, `dnsutils`, `e2fsprogs`, `git`, `gptfdisk`, `htop`, `iproute2`, `lsblk` (`util-linux`), `mdadm`, `parted`, `pciutils`, `tmux`, `usbutils`, `vim`, `xfsprogs`. Each package carries an inline comment describing its recovery purpose
- [ ] T018 [US1] Create `modules/sd/bootstrap.nix`: `bob` user with `operatorPubkey` as authorized key, sshd key-only (`PasswordAuthentication = false` at this layer — W-003 deferral applies only to per-host steady-state, not bootstrap), DHCP via systemd-networkd on the cluster VLAN, hostname placeholder, imports `modules/sd/recovery-utils.nix`. Does NOT import `modules/cluster/*`
- [ ] T019 [US1] Wire the SD image build path: in `flake.nix` (or wherever `sdImage` is declared), the SD image's module list must be `[ <nvmd sd-image module> modules/sd/bootstrap.nix ]` and MUST NOT include the per-host `configuration.nix`. After Phase 5 lands, ensure no `cluster/common.nix` import sneaks into the SD image set
- [ ] T020 [US1] Add `REBUILD=1` support to `make build-image` in `Makefile`: when set, append `--rebuild` to the `nix build` invocation; default behavior unchanged
- [ ] T021 [US1] Audit the `sdImage` derivation closure: change a comment in `modules/sd/bootstrap.nix`, run `make build-image HOST=hlc-501` without `REBUILD=1`, observe a new derivation hash. If unchanged, fix the closure dependency (this is the actual post-mortem stale-image fix; the `REBUILD=1` flag is the escape hatch, not the fix)
- [ ] T022 [US1] Validate end-to-end: `make build-image HOST=hlc-501` → `make flash-image HOST=hlc-501 DEV=/dev/sdX` → power-cycle Pi → `make smoke-test HOST=hlc-501` green; SSH manually as `bob`, confirm recovery utilities (`mdadm`, `parted`, `lsblk`, `vim`, `git`) are on `$PATH`
- [ ] T023 [US1] On success, `git tag phase2-sd-bootstrap`

**Checkpoint**: US1 deliverable in place — Pi 5 boots from a barebones SD on the new upstream, recovery utilities present, image build cache is honest. This is the MVP.

---

## Phase 4: User Story 2 — Modular per-host configuration for all 9 (+3 deferred) nodes (Priority: P2)

**Goal**: All 12 cluster hosts (`hlc-401..404`, `hlc-501..508`) succeed `nixos-rebuild dry-run --flake .#<host>` from a clean checkout. The three-scope module layering (cluster-common → cluster-hlc → device → per-host) is in place. Adding a new host requires no more than 2 file changes (new `hosts/<hostname>/` directory + `flake.nix` entry). The deferred Pi 4 set (`hlc-402..404`) is configured but not flashed (Constitution §"Cluster Topology").

**Independent Test**: From a clean repo checkout, run `make dry-run HOST=<host>` for each of the 12 host IDs (manual loop or shell `for h in hlc-401 hlc-402 hlc-403 hlc-404 hlc-501 hlc-502 hlc-503 hlc-504 hlc-505 hlc-506 hlc-507 hlc-508; do make dry-run HOST=$h; done`); each exits 0. Optionally, run `make build HOST=<one Pi 4 host>` and `make build HOST=<one Pi 5 host>` to confirm both Pi families realize. (No `dry-run-all` cluster-wide iteration target — that is out of scope per the contract.)

### Implementation for User Story 2

- [ ] T024 [P] [US2] Create `modules/cluster/common.nix` skeleton. **nvmd cluster-common imports** (sd-image baseline + raspberry-pi base — every Pi node needs these regardless of family) live HERE per FR-006, NOT in `mkHlcNode` (T009). Also: declare a baseline-toolbox placeholder package set inline (a duplicate of the recovery utilities by name only — DO NOT `imports = [ modules/sd/recovery-utils.nix ]`, since the SD bootstrap is by design separate from per-host configs per FR-003; replicating the package list inline is the correct way to give cluster nodes the same recovery utilities pre-toolbox without coupling the SD layer). The placeholder is replaced by `modules/shell/utilities.nix` in Phase 6 / US4. Also include: base sshd posture, bash as canonical shell. NO MOTD wiring here (the MOTD module is created in T070, banner content in T071, and both are wired into `cluster/common.nix` via T078 + into `cluster/hlc/default.nix` via T079 — all in Phase 6 / US4 to avoid declaring options against a not-yet-created module). NO custom PS1 (added in US4)
- [ ] T025 [P] [US2] Create `modules/cluster/hlc/default.nix`: sets FQDN domain to `marks.dev`, sets per-cluster DNS pointers (PiHole, Dream Machine fallback), declares the `bob` operator user identity (the actual operator user *module* lands in US4). NO MOTD content here — banner + quote land in Phase 6 / US4 via T071's separate `motd-banner.nix` file (wired into `cluster/hlc/default.nix` by T079)
- [ ] T026 [P] [US2] Create `modules/hardware/rpi4.nix`: Pi-4-specific config (NOT the upstream `nixos-hardware.nixosModules.raspberry-pi-4` import — that ships via `mkHlcNode`'s caller-supplied family arg per T009/T041, so importing it here would duplicate). Includes the nvmd Pi-4 module *if it exists separately from nixos-hardware*; force-disable `boot.loader.generic-extlinux-compatible.enable`; **thermal/overclock settings per FR-027 + R-012** — modest overclock matching passive heatsink: `over_voltage=2`, `arm_freq=1750` (the validated Pi 4 profile; stock 1.5 GHz is the documented fallback if thermal validation T119 shows throttling)
- [ ] T027 [P] [US2] Create `modules/hardware/rpi5.nix`: Pi-5-specific config (NOT the upstream `nixos-hardware.nixosModules.raspberry-pi-5` import — supplied via `mkHlcNode` per T009/T041). Includes the nvmd Pi-5 module *if separate*; NVMe overlay (`dtparam=nvme`); **thermal/overclock settings per FR-027 + R-012** — stock clocks (2.4 GHz; no overclock applied) with the official Active Cooler relied on for kernel-controlled fan curve via standard thermal trip points; no `config.txt` fan-curve override unless a node demonstrates inadequate cooling
- [ ] T028 [P] [US2] Create `modules/cluster/config-txt.nix` (separate file, not folded into `common.nix` — config.txt is a distinct concern per Constitution III modular design) with the headless-server `config.txt` profile per [research.md R-011](./research.md) and FR-025: `gpu_mem=16`, `dtparam=audio=off`, `dtoverlay=disable-bt`, `disable_splash=1`, `boot_delay=0`. Imported from `modules/cluster/common.nix`. Pi-family-specific thermal settings live in T026/T027; this task covers only the cluster-common headless profile
- [ ] T029 [US2] Refactor `hosts/hlc-501/configuration.nix` to import the new layering: `modules/cluster/common.nix`, `modules/cluster/hlc/default.nix`, `modules/hardware/rpi5.nix`. Move any per-host content (hostname, IP) into the host file; everything else moves up the layers
- [ ] T030 [P] [US2] Create `hosts/hlc-401/configuration.nix` (Pi 4 control-plane class): hostname, MAC for DHCP reservation reference, imports `cluster/common`, `cluster/hlc`, `hardware/rpi4`
- [ ] T031 [P] [US2] Create `hosts/hlc-502/configuration.nix` (Pi 5 worker class): hostname, hardware imports as hlc-501
- [ ] T032 [P] [US2] Create `hosts/hlc-503/configuration.nix` (same pattern as hlc-502)
- [ ] T033 [P] [US2] Create `hosts/hlc-504/configuration.nix` (same pattern as hlc-502)
- [ ] T034 [P] [US2] Create `hosts/hlc-505/configuration.nix` (same pattern as hlc-502)
- [ ] T035 [P] [US2] Create `hosts/hlc-506/configuration.nix` (same pattern as hlc-502)
- [ ] T036 [P] [US2] Create `hosts/hlc-507/configuration.nix` (same pattern as hlc-502)
- [ ] T037 [P] [US2] Create `hosts/hlc-508/configuration.nix` (same pattern as hlc-502)
- [ ] T038 [P] [US2] Create `hosts/hlc-402/configuration.nix` (Pi 4, decom-set — config evaluable, NOT flashed)
- [ ] T039 [P] [US2] Create `hosts/hlc-403/configuration.nix` (decom-set; same pattern as hlc-402)
- [ ] T040 [P] [US2] Create `hosts/hlc-404/configuration.nix` (decom-set; same pattern as hlc-402)
- [ ] T041 [US2] In `flake.nix`, add 11 new `nixosConfigurations` entries via `mkHlcNode`: `hlc-401..404` (with `nixos-hardware.nixosModules.raspberry-pi-4`) and `hlc-502..508` (with `nixos-hardware.nixosModules.raspberry-pi-5`)
- [ ] T042 [US2] Validate: run `make dry-run HOST=<host>` for each of the 12 hosts (`for h in hlc-401 hlc-402 hlc-403 hlc-404 hlc-501 hlc-502 hlc-503 hlc-504 hlc-505 hlc-506 hlc-507 hlc-508; do make dry-run HOST=$h || break; done`) — every host evaluates from a clean checkout
- [ ] T043 [US2] Validate: `make build HOST=hlc-401` succeeds (one Pi 4 toplevel realizes)
- [ ] T044 [US2] Validate: `make build HOST=hlc-502` succeeds (one Pi 5 toplevel realizes)
- [ ] T045 [US2] Validate SC-003 by hypothesis: pretend to add `hlc-509`; confirm only `hosts/hlc-509/configuration.nix` and one `flake.nix` entry would be needed (don't actually add it; this is a paper validation)
- [ ] T046 [US2] On success, `git tag phase3-per-host-scaffolding`

**Checkpoint**: 12 host configurations evaluable. Module layering is real. No host has been flashed beyond `hlc-501` from US1.

---

## Phase 5: User Story 3 — Full-disk provisioning via disko + nixos-anywhere (Priority: P3)

**Goal**: Each work-set node ends with `/boot` on the SD card, `/` on a 2-disk USB-3 mdadm RAID1 mirror, `/srv/usb` on the same array, and (Pi 5 only) `/srv/ssd` on a 1 TB NVMe. Boot order prefers the USB array; SD recovery is the headless fallback (FR-010..FR-014, FR-026). EEPROM is brought to a known revision and configured declaratively (FR-026 + R-013).

**Independent Test**: Provision `hlc-501` (Pi 5) end-to-end — `nixos-anywhere` runs from gibson against the SD baseline, the Pi reboots into the new root, mounts are correct. Then physically detach the USB drives and power-cycle; the Pi boots into the SD recovery environment with `mdadm` available; smoke-test hits the recovery shell. Re-attach USB drives, normal boot resumes. Repeat the provision on `hlc-401` (Pi 4, no NVMe); `/srv/ssd` is absent without error (FR-010).

### Implementation for User Story 3

- [ ] T047 [P] [US3] Create `disko/rpi4.nix` per [research.md R-004](./research.md): mdadm RAID1 across `usbDevice0` + `usbDevice1` for `/` and `/srv/usb`, both ext4. Device names parameterized via NixOS module arguments (`config.hlc.disko.usbDevice0`, etc.). No NVMe
- [ ] T048 [P] [US3] Create `disko/rpi5.nix`: same USB RAID1 layout as `rpi4.nix`, plus xfs on the NVMe mounted at `/srv/ssd`. Device path parameterized as `config.hlc.disko.nvmeDevice` defaulting to `/dev/disk/by-id/...` (operator confirms exact id during canary)
- [ ] T049 [US3] Wire `disko/rpi4.nix` import into `modules/hardware/rpi4.nix` (or per-host configs); same for `rpi5.nix` into `modules/hardware/rpi5.nix`. Per-host configs declare the actual `hlc.disko.usbDevice0/1` and `nvmeDevice` values
- [ ] T050 [US3] Create `modules/hardware/rpi-eeprom.nix`: one-shot systemd service that runs on first boot of the SD baseline, applies `BOOT_ORDER = 0xf14` and the per-Pi-family EEPROM options from R-013 (BOOT_UART, WAKE_ON_GPIO, POWER_OFF_ON_HALT for Pi 5), idempotent via a marker file in `/boot`. Imported by `modules/sd/bootstrap.nix` so it runs on the bootstrap image, not on the post-provision system
- [ ] T051 [US3] Add `make provision HOST=<host> [IP=<ip>]` target to the Makefile per [contracts/makefile-targets.md](./contracts/makefile-targets.md): wraps `nixos-anywhere --flake .#<host> --target-host root@<IP> --disko-mode disko`. IP derives from HOST per the convention. Refuses if HOST is in the decom-set (`hlc-40[234]`)
- [ ] T052 [US3] Update `make help` text to list the new `provision` target
- [ ] T053 [US3] First-node provision: power-cycle `hlc-501` from current SD-only state, attach the two USB drives + NVMe, boot into SD baseline; from gibson run `make provision HOST=hlc-501`; observe nixos-anywhere's logs; expect Pi reboot at end
- [ ] T054 [US3] Validate provisioning result on `hlc-501`: SSH as `bob`, confirm `/` is on `/dev/md0` (or equivalent mdadm device), `mount | grep -E '(srv/usb|srv/ssd)'` shows both expected mounts, `mdadm --detail /dev/md0` shows clean RAID1 with both members
- [ ] T055 [US3] **Recovery scenario test**: power off `hlc-501`, detach both USB drives, power on; expect SD recovery boot; `make smoke-test HOST=hlc-501` green; SSH manually, run `mdadm --examine` on the (still-attached) NVMe — confirm recovery utilities work
- [ ] T056 [US3] Re-attach USB drives, power cycle; confirm normal post-provision boot resumes (USB array picks up cleanly)
- [ ] T057 [US3] Provision `hlc-502`; smoke-test
- [ ] T058 [US3] Provision `hlc-503`; smoke-test
- [ ] T059 [US3] Provision `hlc-504`; smoke-test
- [ ] T060 [US3] Provision `hlc-505`; smoke-test
- [ ] T061 [US3] Provision `hlc-506`; smoke-test
- [ ] T062 [US3] Provision `hlc-507`; smoke-test
- [ ] T063 [US3] Provision `hlc-508`; smoke-test
- [ ] T064 [US3] Provision `hlc-401` (Pi 4, no NVMe — confirm `/srv/ssd` is simply absent, no error); smoke-test
- [ ] T065 [US3] Validate FR-013 idempotency: re-run `make provision HOST=hlc-501`; expect either no-op or a clear refusal message — NOT silent corruption of the existing array
- [ ] T066 [US3] On success, `git tag phase4-disko-provisioning`

**Checkpoint**: 9 work-set nodes are running NixOS with USB-RAID root + (Pi 5) NVMe `/srv/ssd`. `hlc-402..404` are still on Debian (decom-set, untouched). Recovery boot path verified. Ready for operator UX work.

---

## Phase 6: User Story 4 — Consistent operator shell environment (Priority: P4)

**Goal**: Toolbox, bash baseline, two-form PS1 (local + remote), HLC MOTD, operator user, modular home-manager, and SSH hardening — landed as a **phase-bundle** per Constitution v1.3.2 §IV "Canary scope" + W-001's updated exit plan. `/speckit-implement` executes all module-creation tasks (T067–T077) and wiring tasks (T078–T082) as one batch, then a single canary deploy on `hlc-501` (T083). Smoke-test green → fleet roll across remaining work-set (T088–T096); spot-check (T097); close ledger entries (T098); tag phase exit (T099). On smoke-test fail at canary (T083) → rollback + run `/speckit-debug` skill to bisect the bundle (comment-out new module imports one at a time in `modules/cluster/common.nix` and `modules/cluster/hlc/default.nix`, redeploy, smoke-test) until the breaking module is isolated; fix and re-canary. Operator UX is consistent across silicon (workstation) and the cluster (server) per FR-015..FR-020 and SC-006.

This phase opens with adding the `make update-node` and `make rollback` Makefile targets (T081) — first phase that does live-node config rollouts post-provisioning. See [contracts/makefile-targets.md](./contracts/makefile-targets.md) §"Added Phase 6 US4".

**Independent Test**: SSH as `bob` into any cluster node — HLC MOTD shows, two-line box-drawing PS1 with `☁⛰☁` glyphs, all toolbox commands resolvable, password auth rejected. SSH as `eaglerock` into `silicon` — same toolbox, no HLC MOTD, silicon's local PS1 with `☁⛰☁` substituting `////`. Workstation-only modules (i3, polybar, dunst, dev, etc.) apply only to silicon.

### Implementation for User Story 4 — phase bundle

#### Module creation (file-level work; no on-node deploy)

- [ ] T067 [P] [US4] Create `modules/shell/utilities.nix` with the alphabetical sysadmin toolbox per FR-015 (extends the recovery set): each package on its own line with an inline rationale comment
- [ ] T068 [P] [US4] Create `modules/shell/common.nix`: bash baseline (canonical shell, baseline aliases, no PS1 setting)
- [ ] T069 [P] [US4] Create `modules/shell/prompt.nix` per FR-017 + R-002: local form (silicon-style structure with `☁⛰☁` substituting `////`, color preserved), remote form (two-line box per `remote-ps1.txt`, no color, FQDN). Add `hlc.prompt.mountainGlyph` NixOS option (default: `⛰` + variation selector U+FE0E; fallback: `▲`)
- [ ] T070 [P] [US4] Create `modules/motd/default.nix` per FR-018: parameterized banner module declaring options under a cluster-neutral namespace (`cluster.motd.banner` for the multi-line ASCII string, `cluster.motd.quote` for the quote, `cluster.motd.hostnameLine` defaulting to `Cluster node: <fqdn>`). The module is generic and cluster-agnostic — banner content is injected by the cluster scope, not hard-coded here. The `cluster.*` namespace lets future cluster scopes (e.g. ecto-1) set the same option to their own values without forking the module. Pure Nix-rendered; hostname interpolated from `config.networking.fqdn`
- [ ] T071 [P] [US4] Create `modules/cluster/hlc/motd-banner.nix` as a separate file (NOT folded into `modules/cluster/hlc/default.nix`) so a future cluster scope can supply its own banner without touching the shared MOTD module. Sets `cluster.motd.banner` to the exact post-mortem HLC ASCII art and `cluster.motd.quote` to "Let's build just a happy little cloud." — ~ Bob Ross
- [ ] T072 [P] [US4] Create `modules/users/operator.nix`: `bob` user with `operatorPubkey` as authorized key, member of `wheel` and `docker` groups, passwordless wheel (W-002 site annotated with link to `WORKAROUNDS.md`), bash as login shell. Parameterizable so a future `slimer` user can be added without refactor
- [ ] T073 [P] [US4] Refactor existing `modules/home/base.nix` (present post-Phase-0 reset, inherited from `main`) per [research.md R-009](./research.md). Audit current content first: anything workstation-only (browser config, GUI dotfiles, etc.) moves to `modules/home/workstation.nix` (T075); anything genuinely cross-cutting (neovim baseline, git config with operator's user/email, bash dotfiles, shared aliases) stays in `base.nix`. If `base.nix` is essentially empty / a thin import shim today, expand it per R-009 instead
- [ ] T074 [P] [US4] Create `modules/home/server.nix`: server-only home-manager additions (tmux config tuned for headless work, kubectl/k9s aliases). Imports `modules/home/base.nix`
- [ ] T075 [P] [US4] Create `modules/home/workstation.nix`: imports `modules/home/base.nix` plus existing workstation-only modules (`modules/home/i3.nix`, `polybar.nix`, `dunst.nix`, `dev.nix`, `ui.nix`, `vscode.nix`). `dev.nix` is workstation-only — IDE/desktop dev tooling, no place on a headless cluster node
- [ ] T076 [P] [US4] Create `home/bob.nix` composing `modules/home/base.nix` + `modules/home/server.nix`
- [ ] T077 [P] [US4] Refactor `home/eaglerock.nix` to compose `modules/home/base.nix` + `modules/home/workstation.nix` (remove direct imports of i3/polybar/etc. — those now live behind workstation.nix)

#### Wiring (cluster scope + flake helper updates; still no on-node deploy)

- [ ] T078 [US4] Wire all new modules into `modules/cluster/common.nix`: imports for `modules/shell/utilities.nix` (replacing the toolbox placeholder from T024), `modules/shell/common.nix`, `modules/shell/prompt.nix`, `modules/motd/default.nix`. Also add **SSH hardening** (closes W-003): `services.openssh.settings.PasswordAuthentication = false`, `services.openssh.settings.KbdInteractiveAuthentication = false` — same module since SSH posture is cluster-common. Update FR-020 site annotation
- [ ] T079 [US4] Wire HLC scope content into `modules/cluster/hlc/default.nix`: imports for `modules/cluster/hlc/motd-banner.nix` (sets the HLC banner via `cluster.motd.*` options) and `modules/users/operator.nix` (the `bob` definition). Remove inline `bob` definitions from all per-host configurations created in US2 (T029–T040) — this is the W-001 site removal
- [ ] T080 [US4] Wire `home-manager.users.bob = import ./home/bob.nix` into `mkHlcNode` in `flake.nix` (path relative to flake.nix since the helper is defined there; T009 already brings in `home-manager.nixosModules.home-manager` and stubbed this wire deferred to this task). Per-host configs do not import `home/bob.nix` directly
- [ ] T081 [US4] Add `make update-node HOST=<host>` and `make rollback HOST=<host>` Makefile targets per [contracts/makefile-targets.md](./contracts/makefile-targets.md) §"Added Phase 6 US4". Wrap `sudo nixos-rebuild switch --flake .#<host> --target-host bob@<ip> --use-remote-sudo` and `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<ip> --use-remote-sudo` respectively, with HOST→IP derivation. **Both targets MUST refuse decom-set hosts (`hlc-402`, `hlc-403`, `hlc-404`)** per the contract — same gating as `provision` (T051)
- [ ] T082 [US4] Update `hosts/silicon/configuration.nix` to import `modules/shell/utilities.nix` (workstation toolbox sharing per FR-015). Silicon does NOT import `modules/cluster/*` — workstation profile only. Home-manager mapping for `eaglerock` remains in flake.nix's silicon entry (silicon doesn't use `mkHlcNode`)

#### Bundle canary (single deploy of the full bundle to hlc-501)

- [ ] T083 [US4] **[BUNDLE-CANARY]** Deploy operator-UX bundle to `hlc-501`: `make update-node HOST=hlc-501` then `make smoke-test HOST=hlc-501`. **On smoke-test fail**: `make rollback HOST=hlc-501`, then run `/speckit-debug` skill — the skill drives an incremental bisect (comment-out the new module imports in `modules/cluster/common.nix` one at a time, redeploy via `make update-node`, smoke-test) until the breaking module is isolated. Fix the offending module, then resume with the full bundle. T084..T087 verify aspect-by-aspect once smoke-test is green
- [ ] T084 [US4] Verify MOTD on `hlc-501`: SSH as `bob`, observe banner + `Cluster node: hlc-501.marks.dev` + Bob Ross quote (matches post-mortem reference exactly)
- [ ] T085 [US4] Verify PS1 forms on `hlc-501`: SSH from gibson (kitty terminal, expect remote two-line box-drawing prompt), SSH with `TERM=xterm` from a fresh shell (expect remote form, no color), and console login (expect local form). Verify mountain glyph renders cleanly in all three; if not, flip `hlc.prompt.mountainGlyph` to ASCII fallback per-host
- [ ] T086 [US4] Verify toolbox + home-manager + operator user on `hlc-501`: `which htop && which jq && which mdadm` (toolbox); SSH as `bob` → `nvim --version` opens with baseline config, `git --version` works, tmux config loaded (home-manager); `id bob` shows wheel + docker membership, `sudo -n true` succeeds (operator + W-002)
- [ ] T087 [US4] Verify SSH hardening on `hlc-501`: from gibson, `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no bob@hlc-501.marks.dev` MUST be rejected; key-only login still works (W-003 closure)

#### Fleet roll (serial; smoke-test gate per host)

- [ ] T088 [US4] Apply bundle to `silicon`: `make silicon-switch`. Verify workstation profile intact (i3/polybar/dunst/dev still functional), toolbox shared (same `which htop` resolves), local PS1 with `☁⛰☁` substituting `////`, no HLC MOTD
- [ ] T089 [US4] Roll bundle to `hlc-502`: `make update-node HOST=hlc-502` + `make smoke-test HOST=hlc-502`. On fail: `make rollback`; investigate node-local issue (canary was green, so failure is host-specific); fix or note before continuing
- [ ] T090 [US4] Roll bundle to `hlc-503` + smoke-test
- [ ] T091 [US4] Roll bundle to `hlc-504` + smoke-test
- [ ] T092 [US4] Roll bundle to `hlc-505` + smoke-test
- [ ] T093 [US4] Roll bundle to `hlc-506` + smoke-test
- [ ] T094 [US4] Roll bundle to `hlc-507` + smoke-test
- [ ] T095 [US4] Roll bundle to `hlc-508` + smoke-test
- [ ] T096 [US4] Roll bundle to `hlc-401`: `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`

#### Post-roll verification + close-out

- [ ] T097 [US4] Fleet spot-check: SSH as `bob` to one Pi 5 worker (e.g. `hlc-505`) and to `hlc-401` — confirm MOTD, PS1, toolbox, home-manager all green. SSH as `eaglerock@silicon` separately — confirm workstation-only behavior retained (i3/polybar still up; no HLC MOTD)
- [ ] T098 [US4] Update `WORKAROUNDS.md`: mark W-001 Resolved (date YYYY-MM-DD) — operator-UX bundle deployed via single canary per Constitution v1.3.2 §IV phase-bundle path; mark W-003 Resolved (date YYYY-MM-DD) — SSH hardening live on all 9 work-set nodes. W-002 stays open (deferred to future secrets-mgmt feature spec)
- [ ] T099 [US4] On success, `git tag phase5-operator-ux`

**Checkpoint**: Operator UX consistent across all NixOS hosts. Inline-host workaround retired (W-001 closed). SSH hardened (W-003 closed). Only W-002 (passwordless wheel) remains open as expected.

---

## Phase 7: User Story 5 — k3s OS-level prerequisites (Priority: P5)

**Goal**: Every in-scope node has k3s, k9s, container runtime dependencies, kernel modules, sysctls, and a `k` shell alias installed. The k3s service unit is enabled but stopped; no cluster state on disk. The follow-on cluster-bootstrap spec only needs to drop config and start the unit (FR-021..FR-023, R-003, SC-007).

**Independent Test**: On any work-set node, `k3s --version`, `k9s --version`, and `k version --client` all succeed. `systemctl is-enabled k3s` reports enabled; `systemctl is-active k3s` reports inactive. No `/var/lib/rancher/k3s/` cluster state on disk.

### Implementation for User Story 5

- [ ] T100 [US5] Create `modules/k8s/prereqs.nix` per [research.md R-003](./research.md): `services.k3s.enable = true`, `systemd.services.k3s.wantedBy = lib.mkForce [ ]`, `pkgs.k9s`, shell alias `k = kubectl` in the bash baseline, kernel modules (`br_netfilter`, `overlay`), sysctls (`net.bridge.bridge-nf-call-iptables = 1`, `net.ipv4.ip_forward = 1`, etc.) per upstream k3s requirements. **Container runtime**: rely on k3s's embedded containerd (the default; `services.k3s` wires it). Do NOT install system `containerd`/`runc` packages — adding them risks socket/cgroup contention with the embedded runtime. If a future need surfaces (e.g. `services.k3s.disableAgent = true`), document the system runtime install as a separate concern then
- [ ] T101 [US5] Import `modules/k8s/prereqs.nix` from `modules/cluster/common.nix`
- [ ] T102 [US5] Apply k3s prereqs to `hlc-501`: `make update-node HOST=hlc-501` + `make smoke-test`
- [ ] T103 [US5] Verify on `hlc-501`: `ssh bob@hlc-501 'k3s --version && k9s --version && k version --client'` all exit 0
- [ ] T104 [US5] Verify on `hlc-501`: `ssh bob@hlc-501 'systemctl is-enabled k3s'` returns `enabled`; `systemctl is-active k3s` returns `inactive`
- [ ] T105 [US5] Verify on `hlc-501`: `ssh bob@hlc-501 'lsmod | grep -E "br_netfilter|overlay"'` shows modules loaded; `sysctl net.ipv4.ip_forward` returns 1
- [ ] T106 [US5] Verify on `hlc-501`: no cluster state directory at `/var/lib/rancher/k3s/server/db/` (or equivalent)
- [ ] T107 [US5] Roll k3s prereqs to remaining Pi 5 work-set: serially run `make update-node HOST=<host>` + `make smoke-test HOST=<host>` for each of `hlc-502..508`; per-host repeat the verifications from T103..T106
- [ ] T108 [US5] Roll k3s prereqs to `hlc-401`: `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`; repeat the verifications
- [ ] T109 [US5] On success, `git tag phase6-k3s-prereqs`

**Checkpoint**: All 9 work-set nodes are at the spec's terminal state. The follow-on cluster-bootstrap spec begins from here — no more OS-level work needed.

---

## Phase 8: Polish & cross-cutting validation

**Purpose**: Verify the spec's success criteria empirically; close out documentation; prepare for the follow-on spec.

- [ ] T110 [P] Validate SC-001: time the workflow `make build-image HOST=<a fresh Pi 5> → flash → power-on → make smoke-test` for one cold node; expect ≤ 30 minutes operator wall-clock excluding raw `dd` time
- [ ] T111 [P] Validate SC-002: on a clean checkout (`git clone` to /tmp), run `make dry-run HOST=<host>` for each of the 12 hosts via the shell loop above; expect exit 0 with no manual edits
- [ ] T112 [P] Validate SC-005: pick any work-set node, detach USB drives, power-cycle, confirm SD recovery boot + `mdadm` available; document the recovery time and any surprises
- [ ] T113 [P] Validate SC-006: SSH as `bob` to any cluster node — confirm MOTD per spec, toolbox on `$PATH`, two-line remote PS1; SSH as `eaglerock` to silicon — confirm same toolbox, no HLC MOTD, local PS1 with cluster-themed glyphs
- [ ] T114 [P] Validate SC-007: across all 9 work-set nodes, `k3s --version`, `k9s --version`, `k version --client` succeed; no cluster state on disk anywhere
- [ ] T115 [P] Validate SC-008: change a comment in `modules/sd/bootstrap.nix`, run `make build-image HOST=hlc-501` without `REBUILD=1`, observe new image hash. The post-mortem's stale-image vector stays closed
- [ ] T116 Update `README.md` (top-level) if its quick-reference drifts from the new operator workflow (Makefile targets, IP convention, phase tags)
- [ ] T117 Run `/speckit-analyze` post-implementation; expect a clean pass (no CRITICAL or HIGH findings; FR coverage table fully populated against tagged commits)
- [ ] T118 Confirm `WORKAROUNDS.md` ledger state: W-001 Resolved, W-002 open (deferred to next feature), W-003 Resolved
- [ ] T119 [P] Validate FR-027 thermals on `hlc-401`: under sustained CPU load (e.g. `stress-ng --cpu $(nproc) --timeout 600s` from gibson via SSH) with the modest overclock applied (`over_voltage=2`, `arm_freq=1750` per R-012), confirm the SoC temperature stays under the throttle threshold and `vcgencmd get_throttled` reports 0x0. If throttling observed, drop `hlc-401` to stock 1.5 GHz per R-012 follow-up and re-test
- [ ] T120 [P] Validate SC-004 explicitly: confirm the operator workflow used to bring up `hlc-401` (Pi 4) is identical to the one used for `hlc-501` (Pi 5) at the Makefile-target level — `make build-image`, `make flash-image`, `make provision`, `make update-node`, `make smoke-test` all invoked the same way, with Pi family selected only by per-host configuration (no `build-image-rpi4` / `build-image-rpi5` aliases, no Pi-family conditionals in the Makefile)
- [ ] T121 Extract `docs/operator-runbook.md` from `quickstart.md`: the runbook is a living, post-001 operator reference covering daily operational tasks (build/flash a node, provision, canary a config change, recover from a degraded array, roll back a bad change). `quickstart.md` stays spec-scoped (the Phase 0..6 implementation runbook for THIS spec); `docs/operator-runbook.md` is the general reference that survives spec close. Cross-link both ways
- [ ] T122 On full validation green, `git tag feature-001-complete` — this is the entry point for the follow-on cluster-bootstrap spec

**Checkpoint**: Feature complete. Ready for `/speckit-specify` of the next feature (cluster bootstrap, joining nodes, k3s configuration).

---

## Dependencies

- **Phase 0** (operator-managed) blocks all phases. Tag `phase0-baseline-reset` is the entry condition for T001.
- **Phase 1** (Setup) blocks **Phase 2** (Foundational).
- **Phase 2** (Foundational) blocks all user-story phases.
- **US1** (Phase 3) is the MVP. Stops here for a minimum-viable delivery: one Pi 5 boots cleanly on the new upstream.
- **US2** (Phase 4) depends on US1 (`mkHlcNode` and the upstream swap must be working before adding 11 hosts).
- **US3** (Phase 5) depends on US2 (per-host configurations must exist before disko schemas attach to them).
- **US4** (Phase 6) depends on US2 (module layering must be in place before reintroducing toolbox/PS1/MOTD/etc.). Largely independent of US3 — operator could parallelize if confident.
- **US5** (Phase 7) depends on US2 (needs `modules/cluster/common.nix` to import from). Independent of US3 and US4 — can be done before, after, or in parallel with them once US2 is green.
- **Phase 8** (Polish) depends on US1..US5 all being green.

## Parallel execution opportunities

- **Within US2** (T030..T040): the 11 new per-host configuration files can be created in parallel — they're separate files with no inter-dependencies. The `flake.nix` entries (T041) collapses to one task that gathers all of them.
- **Within US4**: module-creation tasks T067–T077 are parallel-safe (different files; 11 [P] tasks). Wiring tasks T078–T082 are sequential (touch shared files: `modules/cluster/common.nix`, `modules/cluster/hlc/default.nix`, `flake.nix`, `Makefile`, `hosts/silicon/configuration.nix`). Bundle canary + verify tasks T083–T087 are sequential on `hlc-501`. Fleet-roll tasks T088–T096 are serial by safety design (Constitution IV — one node at a time).
- **Across US3/US4/US5**: once US2 is green, the three are mostly independent at the file level. Parallel across stories is operator's call; the safer default is serial because each Constitution IV gate is per-node, not per-story.
- **Within Phase 8** (T110..T115, T119, T120): all validation tasks are read-only spot-checks; trivially parallel. T121 (runbook extraction) writes a new doc and is sequential; T122 is the final tag and runs last.

## Implementation strategy

**MVP scope**: User Story 1 (Phase 3, T017..T023). One Pi 5 boots a barebones SD on the new upstream, recovery utilities present, image build cache is honest. This alone delivers the post-mortem's "Phase 1" goal — restored, working baseline on the correct upstream.

**Incremental delivery**: After MVP, each subsequent phase tags a recoverable state. Phase exits are bisect anchors. The operator can stop at any phase tag and still have a coherent, working system; the cluster simply has fewer features each time you stop earlier.

- Stop at `phase2-sd-bootstrap` → Pi 5 boots cleanly on nvmd, barebones SD; recovery image works.
- Stop at `phase3-per-host-scaffolding` → 12 host configs evaluable, but only `hlc-501` flashed.
- Stop at `phase4-disko-provisioning` → 9 work-set nodes running NixOS with USB-RAID + NVMe, but operator UX is still bare.
- Stop at `phase5-operator-ux` → polished operator experience, ready for k3s.
- Stop at `phase6-k3s-prereqs` → spec complete; the follow-on cluster-bootstrap spec begins here.

**Per-phase cadence** (Constitution IV):

1. Read the phase's section in [quickstart.md](./quickstart.md).
2. Run pre-conditions (`make dry-run` + `make build` for affected hosts).
3. Implement the tasks in this list for that phase. **Implementation chunk size is operator's call** — phase-level batch (one canary per phase, US4-style bundle), per-module (one canary per module, original W-001 cadence), or any sub-bundle in between. Constitution v1.3.2 §IV admits all three; the only invariant is the canary + smoke-test gate before fleet roll. Larger chunks → bisect-on-fail via `/speckit-debug` if the canary smoke-test goes red.
4. **Canary on the designated node** (`hlc-501` for cluster work; silicon for workstation work). The canary scope is the change set chosen in step 3.
5. **Smoke-test green** (`make smoke-test HOST=<host>`). On red and the change set is a bundle → run `/speckit-debug` to bisect; on red and the change set is single-module → diagnose the module directly.
6. Roll to remaining work-set nodes serially.
7. Tag the phase exit.
8. Anything surprising → stop, raise the conflict (Constitution VIII), do not push past unexplained state.

## Notes

- Tests as separate test-files are NOT in scope. The verification model for this NixOS config repo is `dry-run` → `build` → `canary` → `smoke-test`; these are encoded as explicit tasks in each phase rather than as `tests/` directory artifacts.
- `tasks.md` is a living document. If implementation surfaces a sub-step that wasn't anticipated, add it (and re-run `/speckit-analyze` if the addition is structurally significant).
- Parallel `[P]` markers indicate file-level independence; they do NOT override Constitution IV's one-node-at-a-time canary discipline.
