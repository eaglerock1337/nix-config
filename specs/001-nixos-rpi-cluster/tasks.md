# Tasks: NixOS RPi Cluster Foundation (v2)

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Test tasks are NOT included. This is a NixOS configuration repo; the verification model is `dry-run` → `build` → `update-node` (one host) → `smoke-test` (Constitution §"Safety & Change Management"), not unit/integration tests. Operator manually canaries by running `update-node` on the canary node, verifying with `smoke-test`, then proceeding to the rest of the work-set (or `make rollback` if smoke-test fails). **Canary scope** = the change set being deployed; per Constitution v1.3.3 §IV both per-module and phase-bundle scopes are admissible (bundle path additionally requires `/speckit-debug` on smoke-test fail to bisect to the breaking module). Automated single-command canary is out of scope for this spec.

**Smoke-test definition** (updated 2026-05-02): `make smoke-test HOST=<host>` removes SSH host key entries from `~/.ssh/known_hosts` for both the node IP and hostname, pings the node IP for reachability (`ping -c 1 -W 3`), then verifies non-PTY SSH login succeeds on the hostname (no `-t` flag; PTY mode caused Pi login hangs during testing; command: `uname -a`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1..US5)
- **[X]**: Task complete

---

## Phase 1: Setup

**Purpose**: Baseline reset to `main` running-code state + nvmd upstream swap + foundational Makefile targets.

- [X] T001 Tag pre-reset snapshot: `git tag pre-reset-2026-04-29`
- [X] T002 Restore main running code via `git checkout main -- flake.nix flake.lock Makefile hosts/silicon hosts/hlc-501 home/eaglerock.nix modules/home modules/hosts modules/hardware/x1-carbon.nix`
- [X] T003 Remove failed-attempt-only files via `git rm -r hosts/hlc-{401,402,403,404,502,503,504,505,506,507,508} modules/cluster modules/motd modules/shell modules/users modules/hardware/rpi4.nix modules/hardware/rpi5.nix` and `git rm -f hlc-output.txt lshw-output.txt`
- [X] T004 Commit baseline reset: `git commit -m "Phase 0: baseline reset — running code to main, context kept"` then `git tag phase0-baseline-reset`
- [X] T005 [FR-001] Update `flake.nix`: remove `raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix"`, add `nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi"`, re-add `operatorPubkey` constant and `mkHlcNode` helper, add `disko`/`nixos-anywhere`/`sops-nix` inputs
- [X] T006 Run `nix flake update nixos-raspberrypi disko nixos-anywhere sops-nix` (input-scoped; do NOT run bare `nix flake update` to avoid bumping nixpkgs/home-manager on the same commit). Commit `flake.nix` and `flake.lock` together.
- [X] T007 Add Phase 1 Makefile targets to `Makefile`: `dry-run HOST=<host>` (gibson: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`; silicon: `sudo nixos-rebuild dry-run --flake .#<host>`), `build HOST=<host>` (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L`), `smoke-test HOST=<host>` (remove known_hosts for IP + hostname, then `ssh bob@<IP> uname -a` and `ssh bob@<HOST> uname -a`, no `-t`), `ip HOST=<host>` (pure shell HOST→IP derivation per HLC convention: `hlc-VNN` → `10.23.50.<V*10+NN>`)
- [X] T008 Validate: `make build HOST=hlc-501` succeeds; `make build-image HOST=hlc-501` succeeds; `make flash-image HOST=hlc-501 DEV=/dev/sdX`; insert SD into `hlc-501`, power on, run `make smoke-test HOST=hlc-501` — green. Tag `phase1-nvmd-swap`.

**Checkpoint**: ✅ Phase 1 complete. `hlc-501` boots on nvmd fork; smoke-test green.

---

## Phase 2: Foundational

**Purpose**: No additional foundational tasks. The nvmd swap (Phase 1) was the sole blocking prerequisite. All Makefile safety-gate targets (`dry-run`, `build`, `smoke-test`, `ip`) are in place.

**Checkpoint**: Foundation ready. User story implementation can begin.

---

## Phase 3: User Story 1 — SD Bootstrap Rebuild (Priority: P1)

**Goal**: Barebones SD bootstrap config (bob + key + recovery utils + DHCP only) separated from per-host service modules. Stale-image bug closed by derivation closure correctness.

**Independent Test**: Build the new SD image for `hlc-501`, flash, boot, smoke-test green. Change a comment in `modules/sd/bootstrap.nix`, rebuild without `REBUILD=1`, confirm the resulting image hash differs (FR-004 cache invariant — the post-mortem's stale-image vector is closed).

- [X] T009 [US1] Create `modules/sd/recovery-utils.nix`: define `environment.systemPackages` list — alphabetically sorted, one-line inline comment per package. Original set: `curl`, `dmidecode`, `dnsutils`, `e2fsprogs`, `git`, `gptfdisk`, `htop`, `iproute2`, `util-linux` (lsblk), `mdadm`, `parted`, `pciutils`, `tmux`, `usbutils`, `vim`, `xfsprogs`. **Post-completion additions** (SSH debugging, 2026-05-02): `ethtool`, `lsof`, `strace`, `sysstat`, `tcpdump`, plus `hlc-triage` diagnostic capture script. Overlap with `modules/shell/utilities.nix` intentional per FR-003; SD bootstrap is an isolated closure that must not import the cluster toolbox module.
- [X] T010 [US1] Create `modules/sd/bootstrap.nix`: `imports = [ ./recovery-utils.nix ]`; bob user with operator key, openssh key-only, DHCP, hostname placeholder. Do NOT import per-host service modules, `modules/cluster/*`, `modules/hardware/*`, or `modules/k8s/*`. **Post-completion additions** (SSH debugging, 2026-05-02): W-004 (`pam_systemd` disabled), W-006 (firewall/conntrack disabled), IPv6 off, volatile journal, tmpfs mounts, hang-watcher timer for automated SSH-port triage capture. All additions are bootstrap-scoped; provisioned nodes unaffected.
- [X] T011 [US1] Update `flake.nix` SD image build path: add `mkHlcBootstrap` helper and `packages.aarch64-linux` block so SD images are separate derivations from `nixosConfigurations`. Each image: Pi base module + `sd-image` + `modules/sd/bootstrap.nix` + hostname only. Per-host service modules, cluster scope, hardware scope, and k8s scope MUST NOT appear in the SD image closure. `make build-image HOST=<host>` builds `.#packages.aarch64-linux.<host>-sdImage`. Verify with `nix build .#packages.aarch64-linux.hlc-501-sdImage --dry-run`.
- [X] T012 [US1] Add `REBUILD=1` opt-in to `make build-image` in `Makefile`: when `REBUILD=1` is set, append `--rebuild` to the underlying `nix build` invocation. Default behavior (no flag) relies on Nix content-addressing (FR-004).
- [X] T013 [US1] Validate cache invariant: (a) run `make build-image HOST=hlc-501` and record the output store path; (b) change a comment in `modules/sd/bootstrap.nix`; (c) run `make build-image HOST=hlc-501` again without `REBUILD=1`; (d) confirm the output store path changed. This validates FR-004 — the derivation closure correctly depends on `modules/sd/bootstrap.nix`.
- [X] T014 [US1] Flash rebuilt SD: `make flash-image HOST=hlc-501 DEV=/dev/sdX`. Insert into `hlc-501`, power on, wait ~5 minutes, run `make smoke-test HOST=hlc-501` — must be green.
- [X] T015 [US1] Validate recovery utils on `hlc-501`: `ssh bob@hlc-501 "which mdadm parted vim git curl"` — all MUST resolve. Confirm `uname -a` reports `NixOS aarch64`.
- [X] T016 [US1] Commit with message describing SD bootstrap separation and cache-invariant fix. Tag `phase3-sd-bootstrap`.

**Checkpoint**: US1 complete. SD bootstrap boots, cache invariant verified, smoke-test green.

---

## Phase 4: User Story 2 — Modular Per-Host Configuration (Priority: P2)

**Goal**: All 12 host configurations (`hlc-401..404`, `hlc-501..508`) evaluate via `make dry-run` from a clean checkout. Three-scope module layering in place.

**Independent Test**: From a clean checkout, `make dry-run HOST=hlc-<N>` succeeds for all 12 hosts. Adding a stub `hosts/hlc-509/configuration.nix` + flake entry requires no other edits.

- [X] T017 Create `modules/cluster/common.nix` structural skeleton: set `networking.domain = "marks.dev"`; set `services.openssh.enable = true`; set `users.mutableUsers = false`. Add stub import comments `# TODO Phase 6: imports = [ ../shell/utilities.nix ../shell/common.nix ../shell/prompt.nix ../motd/default.nix ../users/operator.nix ]` so the wiring point is explicit. Do NOT import stub-free module paths that don't exist yet.
- [X] T018 Create `modules/cluster/hlc/default.nix`: import `modules/cluster/common.nix`; set `networking.domain = "marks.dev"` — NixOS computes `config.networking.fqdn` as `"${hostName}.${domain}"` automatically; do NOT attempt to assign `networking.fqdn` directly (it is a read-only derived option and will fail evaluation); add placeholder `hlc.motd.banner = ""` option (populated Phase 6).
- [X] T019 [P] Create `modules/hardware/rpi4.nix` stub: set `nixpkgs.hostPlatform = "aarch64-linux"`; import nvmd's RPi 4 hardware module (check `github:nvmd/nixos-raspberrypi` README or `flake.nix` outputs for the Pi 4 / bcm2711 module path — likely `nixosModules.raspberry-pi-4` or similar). Add stub comments `# TODO Phase 5: config.txt + EEPROM + thermal`.
- [X] T020 [P] Create `modules/hardware/rpi5.nix` stub: same structure as rpi4 but for Pi 5 / bcm2712, importing nvmd's RPi 5 hardware module. Add stub comments `# TODO Phase 5: config.txt + EEPROM + NVMe + thermal`.
- [X] T021 [P] Create per-host files for Pi 5 work-set: for each of `hlc-501` through `hlc-508`, create `hosts/hlc-5NN/configuration.nix` with `imports = [ ../../modules/cluster/hlc/default.nix ../../modules/hardware/rpi5.nix ]`, `networking.hostName = "hlc-5NN"`, and `hlc.disko.usbDevice0 = "PLACEHOLDER"`; `hlc.disko.usbDevice1 = "PLACEHOLDER"`; `hlc.disko.nvmeDevice = "PLACEHOLDER"` (real device paths filled in Phase 5 before provisioning; USB: by-path per FR-010a, NVMe: `/dev/nvme0n1`).
- [X] T022 Create `hosts/hlc-401/configuration.nix`: `imports = [ ../../modules/cluster/hlc/default.nix ../../modules/hardware/rpi4.nix ]`, `networking.hostName = "hlc-401"`, USB device placeholders, `hlc.disko.nvmeDevice = null`.
- [X] T023 [P] Create deferred Pi 4 host files for `hlc-402`, `hlc-403`, `hlc-404`: same structure as hlc-401. Add comment in each: `# DEFERRED: config-only per Constitution cluster-topology; do NOT flash or run nixos-rebuild switch`.
- [X] T024 Update `flake.nix` `nixosConfigurations` to include all 12 hosts (`hlc-401..404`, `hlc-501..508`). Each entry: `lib.nixosSystem { system = "aarch64-linux"; modules = [ hosts/<hostname>/configuration.nix ]; }` (plus home-manager if already wired at the flake level).
- [X] T025 Run `make dry-run` for all 12 hosts and confirm each succeeds: `make dry-run HOST=hlc-401`, `make dry-run HOST=hlc-402`, `make dry-run HOST=hlc-403`, `make dry-run HOST=hlc-404`, `make dry-run HOST=hlc-501` through `make dry-run HOST=hlc-508`. Fix any evaluation errors before proceeding.
- [X] T026 SC-003 testability: create `hosts/hlc-509/configuration.nix` (copy of hlc-501 with `networking.hostName = "hlc-509"`) and add `hlc-509` entry to `flake.nix`. Run `make dry-run HOST=hlc-509` — must succeed. Confirm only 2 file changes were required. Remove `hosts/hlc-509/` and revert the flake entry after verification.
- [X] T027 Commit with message describing layered scaffolding and all-12 dry-run validation. Tag `phase4-scaffolding`.

**Checkpoint**: US2 complete. All 12 hosts evaluate from clean checkout. SC-002 and SC-003 verified.

---

## Tooling — `/speckit-debug` Skill *(retroactive: added 2026-05-01, FR-028)*

**Goal**: Create the `/speckit-debug` Claude Code skill before Phase 6 bundle-canary begins. Required by Constitution §IV bisect procedure and referenced throughout tasks.md/plan.md.

- [X] T027a [FR-028] Create `.claude/skills/speckit-debug/skill.md`. Rules per FR-028: operator-initiated (no auto-context load at start); all diagnostic steps network-only/SSH from gibson (MUST NOT suggest physical access; Makefile targets preferred per Constitution §VII); operator-trust model (observations are ground truth; challenge only via explicit question, never silent pivot); conversational format (no fixed output template); reads constitution + `specs/001-nixos-rpi-cluster/post-mortem-26-04-29.md` at invocation; spec/plan on demand. Verify by invoking `/speckit-debug` and confirming the skill loads correctly.
- [X] T027b [FR-003] Architecture change: separate SD bootstrap images from provisioned `nixosConfigurations`. (1) Remove `sd-image` module from `modules/hardware/rpi{4,5}.nix`; add `fileSystems."/" = lib.mkDefault { device = "/dev/md0"; fsType = "ext4"; }` placeholder (safe since sd-image gone; disko overrides in Phase 5). (2) Add `mkHlcBootstrap` helper to `flake.nix` — builds SD image from Pi base module + sd-image + `modules/sd/bootstrap.nix` + hostname only. (3) Add `packages.aarch64-linux` block with 12 SD image entries (all Pi 4s included for pre-cutover readiness; decom guard applies to remote ops only, not local SD builds). (4) Update all 12 per-host `configuration.nix` to import `modules/cluster/hlc/default.nix` instead of `modules/sd/bootstrap.nix`. (5) Update `make build-image` to reference `packages.aarch64-linux.$(HOST)-sdImage`. (6) Fix latent syntax bug in `modules/cluster/hlc/default.nix` (missing `#` on comment lines). (7) Close W-005. All 12 dry-runs green; SD image derivations evaluate. Resolves W-005 via architecture, not Phase 5 edits.

---

## Phase 5: User Story 3 — Full-Disk Provisioning with Two-Phase Install (Priority: P3)

**Goal**: Two-phase provisioning installs per-host NixOS onto USB-RAID root + NVMe data volume. Stage 2 installs a provision-minimal config (small closure, fast copy); stage 3 pushes full config via `update-node` (differential `nix copy`). EEPROM boot order locked to USB-first, SD-fallback. Recovery scenario verified. RAID-retry path available for failed installs where disko already succeeded.

**Independent Test**: Provision `hlc-501` end-to-end — stage2 completes without timeout (closure is small), mid-provision smoke-test clears stale SSH keys, stage3 pushes full config, final smoke-test green. Compare closure sizes (provision vs full). Detach USB drives, power-cycle — SD recovery boots with `mdadm` available. Re-attach, normal boot. Repeat on `hlc-401` (Pi 4, no NVMe; `/srv` absent without error).

### Disko Schemas + Hardware Modules

- [X] T028 [P] [US3] Create `disko/rpi5.nix`: define `disko.devices` for Pi 5 layout — (a) SD card `vfat` for `/boot`; (b) `mdadm` RAID1 across `config.hlc.disko.usbDevice0` and `usbDevice1`, single ext4 partition for `/` (full array ~28.6 GiB; drives are ~30 GB / ~28.6 GiB usable); (c) `config.hlc.disko.nvmeDevice` xfs for `/srv`. USB devices identified by `/dev/disk/by-path/` (FR-010a); NVMe by `/dev/nvme0n1`. Default mode: `disko` (not `disko-destroy`) for FR-013 idempotency. Note: `fileSystems."/"` placeholder already present in `modules/hardware/rpi5.nix` (`lib.mkDefault`); disko will override it with the real device — no manual edit needed. W-005 already closed.
- [X] T029 [P] [US3] Create `disko/rpi4.nix`: same as `disko/rpi5.nix` but without the NVMe device block. `/srv` mount point MUST NOT be defined. `hlc.disko.nvmeDevice` option present but nullable; Pi 4 provisioning succeeds when it is `null`. Note: `fileSystems."/"` placeholder already present in `modules/hardware/rpi4.nix` (`lib.mkDefault`); disko overrides it. W-005 already closed.
- [X] T030 [US3] Expand `modules/hardware/rpi5.nix` with full config.txt profile (FR-025, R-011): `gpu_mem = 16`, `dtparam = audio=off`, `dtoverlay = disable-bt`, `disable_splash = 1`, `boot_delay = 0`, `dtparam = nvme`. **Pre-implementation research**: fetch the nvmd README (`develop` branch) or inspect `nixosModules.raspberry-pi-5` option set to confirm the exact NixOS option path for config.txt entries (e.g. `raspberry-pi.config` vs `hardware.raspberry-pi.config-txt` vs another surface). Document the confirmed path in a comment in the module. Add Pi 5 thermal: stock clocks 2.4 GHz, kernel-controlled fan curve, no overclock (R-012, FR-027). Note: `boot.loader.raspberry-pi.bootloader = "kernel"` already set (R-015); add `boot.loader.raspberry-pi.configurationLimit = 5` alongside config.txt settings.
- [X] T031 [US3] Expand `modules/hardware/rpi4.nix` with config.txt profile (same headless set minus `dtparam=nvme`; use the config.txt option path confirmed in T030). Add Pi 4 thermal: `over_voltage = 2`, `arm_freq = 1750` (modest overclock, passive heatsink validated; R-012, FR-027). Note: `boot.loader.raspberry-pi.bootloader = "kernel"` already set (R-015); add `boot.loader.raspberry-pi.configurationLimit = 5` alongside config.txt settings.
- [X] T032 [US3] Create `modules/hardware/rpi-eeprom.nix` (FR-026, R-013): `systemd.services.rpi-eeprom-config` one-shot service that applies EEPROM config — `BOOT_ORDER=0xf14`, `BOOT_UART=1` (universal); `WAKE_ON_GPIO=0`, `POWER_OFF_ON_HALT=1` (Pi 5 only). **Pre-implementation research**: verify whether nvmd exposes a `config.hardware.raspberry-pi.variant` option or equivalent for Pi-family detection; if not, define a custom `hlc.piFamily` option (set per-host) or guard on `config.nixpkgs.hostPlatform` attributes. Gate idempotency with marker file `/boot/.eeprom-configured` — service is a no-op if marker exists. `serviceConfig.Type = "oneshot"`; `serviceConfig.RemainAfterExit = true`. Import this module from both `modules/hardware/rpi4.nix` and `modules/hardware/rpi5.nix`.

### Two-Phase Provision Infrastructure (FR-012 amendment, R-016)

- [X] T033 [P] [US3] Create `modules/cluster/hlc/options.nix`: extract shared HLC option declarations from `modules/cluster/hlc/default.nix` — `hlc.prompt.glyph`, `hlc.disko.{usbDevice0, usbDevice1, nvmeDevice, skipNvmeFormat}`. Both `default.nix` (full) and `provision.nix` (minimal) import this file to avoid NixOS duplicate-option declaration errors.
- [X] T034 [P] [US3] Create `modules/cluster/hlc/provision.nix`: minimal cluster module for provisioning. Imports: `./options.nix` (shared option declarations), `./raid-fallback.nix` (initrd RAID for boot), `../../users/operator.nix` (bob user). Inlines essential config from `cluster/common.nix` and `hosts/common.nix`: SSH enabled + key-only auth + root authorized keys, passwordless sudo for wheel, `nix.settings` (flakes, auto-optimise-store, binary caches, trusted-users), `networking.domain = "marks.dev"`, `users.mutableUsers = false`, `system.operator` for bob. Does NOT import: home-manager, `utilities.nix` (60+ pkgs), `shell/common.nix`, `motd.nix`, `prompt.nix`, `hosts.nix` (HLC host-to-IP map — the `/etc/hosts` entries excluded from provision-minimal), git-clone activation.
- [X] T035 [US3] Update `modules/cluster/hlc/default.nix`: add `./options.nix` to imports; remove the inline `options.hlc` block (now in `options.nix`). Verify `make dry-run HOST=hlc-501` still succeeds after this refactor.
- [X] T036 [US3] Update all 12 host configs (`hosts/hlc-{401..404,501..508}/configuration.nix`): add `clusterModule` parameter with default so existing builders work unchanged. One-line change each: `{ clusterModule ? ../../modules/cluster/hlc/default.nix, ... }: { imports = [ clusterModule ... ]; }`. Verify `make dry-run HOST=hlc-501` and `make dry-run HOST=hlc-401` still succeed.
- [X] T037 [US3] Update `flake.nix`: add `mkHlcProvision` builder (like `mkHlcNode` but no home-manager; passes `clusterModule = ./modules/cluster/hlc/provision.nix` via `specialArgs`). Generate `<host>-provision` flake outputs for all 12 hosts (same pattern as `-bare` outputs). No `-provision-bare` variant needed — bare variants are only for the disko phase.
- [X] T038 [US3] Verify closure sizes on silicon or gibson: run `nix build .#nixosConfigurations.hlc-501.config.system.build.toplevel` and `nix build .#nixosConfigurations.hlc-501-provision.config.system.build.toplevel`, then compare with `nix path-info -Sh` on both. Provision closure MUST be significantly smaller than full. Document the size comparison. **Result**: provision-minimal = 2.5 GB, full config = 3.5 GB (~29% smaller). Validates FR-012 two-phase rationale.
- [X] T039 [US3] Run `make dry-run HOST=hlc-501` and `make build HOST=hlc-501` after T033–T038. Both must succeed. Also run `make dry-run HOST=hlc-401` to verify Pi 4 path. Fix any evaluation errors.

### Makefile Targets (Phase 5)

- [X] T040 [US3] Add `make update-node HOST=<host> [IP=<ip>]` to `Makefile`: builds `.#nixosConfigurations.<host>.config.system.build.toplevel` locally, copies closure to remote via `nix copy --to ssh-ng://bob@<IP>`, then activates via `switch-to-configuration switch`. Derives IP from HOST per HLC convention unless `IP=` provided. Refuses decom-set hosts (`hlc-402..404`) with error message.
- [X] T041 [US3] Add `make rollback HOST=<host> [IP=<ip>]` to `Makefile`: wraps `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<IP> --use-remote-sudo`. Same IP-derivation and decom-set guard.
- [X] T042 [US3] Update `make provision` in `Makefile` for two-phase flow: (1) `provision-stage2` uses `--flake .#$(HOST)-provision` instead of `.#$(HOST)`. (2) New `provision-stage3` target: waits for node reboot (poll SSH), runs `smoke-test` (clears stale host keys), then pushes full config via `update-node`, then final `smoke-test`. (3) Composite `provision` becomes: `provision-stage1` → `provision-mount` → `provision-stage2` → `smoke-test` → `provision-stage3` → `smoke-test`. (4) Update `reprovision` composite similarly: `reprovision-stage1` → `provision-mount` → `provision-stage2` → `smoke-test` → `provision-stage3` → `smoke-test` (reprovision-stage1 still uses `$(HOST)-bare` for disko; stage2 uses `-provision` config which has correct fstab including `/srv` since `skipNvmeFormat` defaults to false).
- [X] T043 [US3] Add `make provision-reinstall HOST=<host> [IP=<ip>]` to `Makefile`: RAID-retry path for failed stage2 where disko succeeded but install failed/timed out. Pre-flight: SSH to node, verify RAID array exists in `/proc/mdstat` but root is NOT md-backed (booted from SD — distinguishes "disko ran, install failed" from "fully provisioned node"). Skip `provision-stage1` (disko already done). Run `provision-mount` → `provision-stage2` → `smoke-test` → `provision-stage3` → `smoke-test`. Refuses decom-set hosts. Note: this is the inverse of FR-013's idempotency gate — it requires RAID to exist but refuses if node is already fully provisioned.

### Disaster Recovery Infrastructure (DR-001/DR-002, retroactive: added 2026-05-17)

- [X] T042a [US3] Create `modules/cluster/hlc/hlc-recover-script.nix`: ash-compatible POSIX sh recovery tool for initrd rescue shell. Commands: `status` (block devices, blkid, mdstat, RAID detail, mounts), `mount` (assemble RAID + e2fsck + mount root), `umount`, `raid-boot` (chroot into RAID system, reinstall bootloader), `wipe -y` (stop arrays, zero superblocks, wipefs, sgdisk), `sd-boot` (restore firmware partition from `.bootstrap-backup.tar.gz`). Build-time hostname interpolation for banners. Injected into initrd via `boot.initrd.extraUtilsCommands` in `raid-fallback.nix`.
- [X] T042b [US3] Add `provision-backup-boot` target to `Makefile` (DR-002): before `provision-stage2` overwrites the SD firmware partition with provisioned NixOS boot files, tar the existing bootstrap boot files into `/boot/firmware/.bootstrap-backup.tar.gz`. This backup is used by `hlc-recover sd-boot` to restore the SD bootstrap without reflashing. Integrated into `provision` and `reprovision` composite targets.
- [X] T042c [US3] Add initrd filesystem kernel modules to `raid-fallback.nix`: `vfat`, `fat`, `nls_cp437`, `nls_iso8859_1` — required for the rescue shell to mount the FAT32 firmware partition (`/dev/mmcblk0p1`) during `hlc-recover raid-boot` and `hlc-recover sd-boot`. Without these, `mount` fails with "wrong fs type, missing codepage."
- [X] T042d [US3] Add recovery Makefile targets for initrd rescue operations (DR-001): `make recover-status HOST=<host>` (query rescue state via `hlc-recover status`), `make recover-wipe HOST=<host>` (wipe RAID via `hlc-recover wipe -y`), `make recover-sd-boot HOST=<host>` (restore SD bootstrap boot), `make recover HOST=<host>` (full cycle: wipe → sd-boot → reboot → wait for SD bootstrap → provision). All targets connect as `root@` (initrd dropbear) and refuse decom-set hosts.
- [X] T042e [US3] Add `hlc.rescueIp` NixOS option to `raid-fallback.nix`: per-host static IP for initrd dropbear SSH. Set in each host's `configuration.nix` to match their DHCP reservation so the operator can reach the rescue shell at the same address.

### Device Paths + Provisioning Runs

- [X] T044 [P] [US3] Fill real device paths for `hlc-501`: USB by-path filled (`xhci-hcd.0`=a/left, `xhci-hcd.1`=b/right; confirmed on hlc-501 and hlc-504). NVMe = `/dev/nvme0n1` (confirmed working on hlc-501 as of 2026-05-08; all Pi 5 nodes verified with NVMe present and working).
- [X] T045 [US3] Provision `hlc-501` via two-phase flow: **Pre-conditions**: (1) both USB drives show `usbv3` alias in `/dev/disk/by-path/` (re-seat any that show `usbv2`); (2) NVMe confirmed at `/dev/nvme0n1` (`ls /dev/nvme0n1`). Run `make provision HOST=hlc-501`. Verify: stage2 completes without timeout (small provision-minimal closure), mid-provision smoke-test green (clears stale SSH keys), stage3 pushes full config via `update-node`, final smoke-test green. After reboot, SSH as `bob@hlc-501` and verify: `df -h /` shows mdadm array on `/dev/md127`, `df -h /srv` shows NVMe. **Confirmed 2026-05-17**: provisioned, SD reflashed with DR fixes, RAID boot restored.
- [X] T046 [US3] Verify RAID health: `ssh bob@hlc-501 "sudo mdadm --detail /dev/md/usb-raid"` — both USB devices show as active/in-sync.
- [X] T047 [US3] Recovery test (FR-011, SC-005): power down `hlc-501`; physically detach both USB drives; power on. Wait ~3 min. Run `make smoke-test HOST=hlc-501` — green (SD boots). Verify recovery tools: `make recover-status HOST=hlc-501` (shows no RAID, block devices visible). Also verify `hlc-recover` is available in the initrd rescue shell (if RAID absent, node enters rescue mode with dropbear SSH as `root@`). Re-attach USB drives; power cycle; `make smoke-test HOST=hlc-501` — green (USB array boot).
- [X] T048 [US3] Idempotency test (FR-013): re-run `make provision HOST=hlc-501` on the already-provisioned node. MUST refuse with clear message: `ERROR: <host> has active RAID or md root filesystem — live provisioned node detected.` SD baseline remains intact for retry. Also test `make provision-reinstall HOST=hlc-501` — MUST also refuse (node is fully provisioned with md-backed root, not a failed-install state).
- [X] T049 [P] [US3] Fill device paths for `hlc-502` through `hlc-508`: USB by-path and NVMe (`/dev/nvme0n1`) filled for all Pi 5 hosts. Dry-run green.
- [X] T050 [US3] Provision `hlc-502`: `make provision HOST=hlc-502`. Run `make smoke-test HOST=hlc-502`. Verify mounts. **Confirmed 2026-05-17**.
- [ ] T051 [US3] Provision `hlc-503`: `make provision HOST=hlc-503`. Run `make smoke-test HOST=hlc-503`. **DECOM (2026-05-17)**: hardware defect — USB controller delivers ~350 KB/s sustained writes despite negotiating USB 3.0 (5 Gbps). Confirmed via dd stress test, drive swap to known-good node, PSU/thermal/EEPROM ruled out. Added to `DECOM_HOSTS`. Board to be repurposed (SD-only use). Provision skipped. See W-015.
- [X] T052 [US3] Provision `hlc-504`: `make provision HOST=hlc-504`. Run `make smoke-test HOST=hlc-504`. **Confirmed 2026-05-17**.
- [X] T053 [US3] Provision `hlc-505`: `make provision HOST=hlc-505`. Run `make smoke-test HOST=hlc-505`. **Confirmed 2026-05-17**.
- [X] T054 [US3] Provision `hlc-506`: `make provision HOST=hlc-506`. Run `make smoke-test HOST=hlc-506`. **Confirmed 2026-05-17**.
- [ ] T055 [US3] Provision `hlc-507`: `make provision HOST=hlc-507`. Run `make smoke-test HOST=hlc-507`. **Note**: hlc-507 currently in `DECOM_HOSTS` (hardware issue as of 2026-05-08); skip and return once resolved. See W-016.
- [X] T056 [US3] Provision `hlc-508`: `make provision HOST=hlc-508`. Run `make smoke-test HOST=hlc-508`. **Confirmed 2026-05-17**.
- [X] T057 [US3] Fill real device IDs for `hlc-401` in `hosts/hlc-401/configuration.nix`. Pi 4: USB drives only; `hlc.disko.nvmeDevice = null`.
- [X] T058 [US3] Provision `hlc-401` (Pi 4): `make provision HOST=hlc-401`. After reboot, verify `/srv` does NOT exist (absent without error, FR-010). Verify `/` on mdadm array. Run `make smoke-test HOST=hlc-401` — green.
- [X] T059 [US3] Commit all device-ID updates and provisioning-validated configs. Tag `phase5-provisioned`. **Exception**: hlc-503 (defective USB controller, DECOM 2026-05-17) and hlc-507 (broken USB-C port, DECOM 2026-05-08) excluded — provisioned if/when replacement hardware arrives. All other work-set nodes (hlc-401, 501, 502, 504, 505, 506, 508) provisioned and verified.

**Checkpoint**: US3 complete. All available work-set nodes provisioned via two-phase flow. SC-005 verified. Closure size comparison documented. Nodes in `DECOM_HOSTS` provisioned once hardware issues resolve.

---

## Phase 6: User Story 4 — Operator UX (Priority: P4)

**Goal**: HLC MOTD (Gruvbox-colorized), unified PS1 (Gruvbox 256-color), sysadmin toolbox, modular home-manager, SSH hardening — live across all work-set nodes. W-001 and W-003 closed.

**Independent Test**: SSH as `bob@hlc-501` → Gruvbox-colorized HLC MOTD (banner + `Cluster node: hlc-501.marks.dev` + Bob Ross quote), Gruvbox PS1 (`┌─╸bob@hlc-501 ☁️ 🏔️ ☁️ [~]` / `└──╸$`), all toolbox commands on `$PATH`. SSH as `eaglerock@silicon` → same toolbox, no HLC MOTD, workstation PS1 unaffected.

**Module layout** (per spec Session 2026-05-11 Q16–Q19):

- `modules/hosts/common.nix` — TOP-LEVEL CATCHALL (D1): truly universal — imports shell tier + users/operator; sets nix.settings, time, locale, openssh, allowUnfree; defines universal `nr`/`ndr` shell functions (works on workstation + cluster). NO user-instance definitions, NO PS1, NO docker, NO security policy. Consumed by `modules/hosts/workstation.nix` and `modules/cluster/common.nix`.
- `modules/hosts/workstation.nix` — workstation tier (C4/C7): imports common.nix; adds silicon `programs.bash.promptInit` (Gruvbox PS1), `virtualisation.docker.enable`, `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`. Consumed by silicon only.
- `modules/shell/{utilities,common}.nix` — generic baseline (packages incl. `neovim` + `vim`, bash, aliases, `EDITOR=nvim`); consumed via `modules/hosts/common.nix`.
- `modules/users/operator.nix` — option-driven; option `system.operator = { name; pubkeys; extraGroups ? ["wheel"]; description ? ""; }`; generates `users.users.${name}` ONLY (no security policy). Consumed via `modules/hosts/common.nix`.
- `modules/cluster/{motd,prompt}.nix` — generic cluster-tier mechanism modules. `motd.nix` options `cluster.motd.{banner,quote}`. `prompt.nix` option `cluster.prompt.glyph` (default `"-"`; generic fallback).
- `modules/cluster/common.nix` — imports `../hosts/common.nix` + `./motd.nix` + `./prompt.nix`. Cluster-only security policy (`PasswordAuthentication=false`, `KbdInteractiveAuthentication=false`, `wheelNeedsPassword=false`) lives here so workstations are unaffected. `cloneOperatorRepos` activationScript parameterized via `config.system.operator.name` and gated on `cfg.name != null`.
- `modules/cluster/hlc/default.nix` — HLC scope: defines `hlc.prompt.glyph` option (default `"☁️🏔️☁️"` emoji; text fallback `"☁⛰︎☁"`); sets `cluster.motd.*`, `cluster.prompt.glyph = config.hlc.prompt.glyph`, `system.operator` (bob); REMOVES stale `options.hlc.motd.banner` stub.
- `hosts/silicon/configuration.nix` — silicon scope (C5): imports `modules/hosts/workstation.nix` + workstation modules; sets `system.operator` (eaglerock with description/extraGroups inline).
- `modules/home/{base,server,workstation}.nix` — home-manager tiers; cluster-specific home bits inline in `home/bob.nix`.

**Per-phase cadence (bundle)**: Tasks T060–T073 (all module creation, wiring, and build verification) execute as one batch before a single canary deploy at T074. Smoke-test green → fleet roll (T079–T086). On smoke-test fail at T074: `make rollback HOST=hlc-501`, then `/speckit-debug` bisect (comment-out new imports in `modules/cluster/common.nix` one at a time, re-canary, smoke-test) to isolate the breaking module.

### Create Shell Tier (Bundle — all before canary)

- [X] T060 [P] [US4] Create `modules/shell/utilities.nix`: define `environment.systemPackages = with pkgs; [ ... ]` with the FULL package list copied from existing `modules/hosts/common.nix` (Q18: unify). Includes all current workstation packages — `k9s`, `kubectl`, `kubernetes-helm`, `kind`, `minikube`, `bat`, `eza`, `fd`, `ripgrep`, `fzf`, `dust`, `duf`, `tree`, `zoxide`, `jq`, `yq`, `sd`, `git`, `busybox`, `killall`, `micro`, `less`, `glow`, `htop`, `btop`, `lsof`, `strace`, `iotop`, `dool`, `ncdu`, `efibootmgr`, `caffeine-ng`, `curl`, `wget`, `httpie`, `fping`, `dnsutils`, `iperf3`, `mtr`, `nmap`, `socat`, `rsync`, `openssh`, `gnupg`, `gnutls`, `age`, `pinentry-curses`, `pinentry-gnome3`, `pass`, `tmux`, `entr`, `delta`, `unzip`, `zip`, `file`, `man-db`, `tldr`, `neofetch`, `nh` — plus cluster-only ops tools `mdadm`, `parted`, `pciutils`, `usbutils`, `iproute2`, `tcpdump`, `vim` — plus `neovim` (default editor for all hosts; paired with `EDITOR=nvim` in T061). Preserve thematic section dividers (`# --- Editors & Viewers ---`, etc.). FR-015 requirement: EVERY package MUST have an inline `# comment` describing its purpose; add comments for entries that lack them today. Keep within `with pkgs;` scope.
- [X] T061 [P] [US4] Create `modules/shell/common.nix`: set `programs.bash.enable = true`; `users.defaultUserShell = pkgs.bash`; define `programs.bash.shellAliases = { ll = "ls -la"; la = "ls -A"; ".." = "cd .."; "..." = "cd ../.."; k = "kubectl"; }`; set `environment.variables.EDITOR = "nvim"` (neovim is provided system-wide by T060; vim remains as fallback).

### Create Cluster-Tier Mechanism Modules

- [X] T062 [P] [US4] Create `modules/cluster/prompt.nix`: generic cluster-tier PS1 mechanism. Define option:
  - `cluster.prompt.glyph` (string, default = `"-"`) — central decoration between user@host and cwd. Generic fallback (dash); each cluster overrides in its `modules/cluster/<name>/default.nix`.
  Single unified PS1 (no local/remote distinction) set via `programs.bash.promptInit` (not profile.d — NixOS default promptInit overwrites profile.d scripts). Two-line box-drawing with Gruvbox 256-color palette (109=teal on box-drawing/brackets, 214=gold on user/hostname, 142=green on cwd, 15=bright white on `@`/`$`): `PS1='┌─╸\u@\H <glyph> [\w]\n└──╸\$ '`. `\H` returns short hostname (accepted).
- [X] T063 [P] [US4] Create `modules/cluster/motd.nix`: cluster-tier MOTD mechanism with Gruvbox 256-color styling. Define options under `cluster.motd`:
  - `cluster.motd.banner` (string, no default) — styled ASCII banner shown at SSH login; per-cluster value (HLC: gold borders, teal ASCII art, green "Happy Little Cloud", red "Bob Ross").
  - `cluster.motd.quote` (string, no default) — styled quote/tagline shown after the hostname line.
  ANSI escape bytes embedded via `builtins.fromJSON ''"\u001b"''` (single backslash — Nix indented strings treat `\` as literal). `Cluster node:` line: teal label, gold colon, bright white FQDN. `services.openssh.settings.PrintMotd = true`. Written to `/etc/motd` via `environment.etc."motd".text`.
  Generate `environment.etc."motd".text = "${config.cluster.motd.banner}\nCluster node: ${config.networking.fqdn}\n${config.cluster.motd.quote}\n"`. Set `services.openssh.settings.PrintMotd = true` (or NixOS-appropriate option). This module is generic — HLC values are set in `modules/cluster/hlc/default.nix` (T072).

### Create Option-Driven Operator Module

- [X] T064 [P] [US4] Create `modules/users/operator.nix`: option-driven operator user (ACCOUNT GENERATION ONLY — cluster-only security policy lives in `modules/cluster/common.nix` per T071). Define options under `system.operator`:
  - `system.operator.name` (nullOr str, default null) — login name (e.g. `"bob"`, `"eaglerock"`, `"slimer"`). Null skips account generation.
  - `system.operator.pubkeys` (listOf str, default []) — SSH authorized keys.
  - `system.operator.extraGroups` (listOf str, default = `["wheel"]`) — supplementary groups (HLC bob keeps default; silicon eaglerock sets `["wheel" "networkmanager" "docker"]`).
  - `system.operator.description` (string, default = `""`) — user description (e.g. `"Peter Marks"` for eaglerock, `"HLC cluster operator"` for bob).
  Generate `users.users.${cfg.name} = { isNormalUser = true; extraGroups = cfg.extraGroups; openssh.authorizedKeys.keys = cfg.pubkeys; description = cfg.description; shell = pkgs.bash; }` only when `cfg.name != null`. Module is imported globally via `modules/hosts/common.nix` (cluster + workstation). NO security overrides here — workstations keep NixOS defaults (password sudo, password SSH); cluster security policy is enforced separately.

### Create Home-Manager Tiers

- [X] T065 [US4] Update existing `modules/home/base.nix` (already consumed by silicon): keep current shared content (vim/neovim/git/bash defaults, fontconfig). Fix `programs.bash.shellAliases.ll`/`la` — currently reference `exa` (retired upstream); update to `eza` to match `T060` package set. KEEP `gpnr` alias here (pairs with the universal `nr` shell function in `modules/hosts/common.nix` per T070; useful for both bob on cluster and eaglerock on silicon). Verify no workstation-specific content leaks in here.
- [X] T066 [P] [US4] Create `modules/home/server.nix`: `imports = [ ./base.nix ]`; add server-only config — `programs.tmux = { enable = true; shortcut = "a"; historyLimit = 50000; clock24 = true; }`, `home.sessionVariables.KUBECONFIG = "$HOME/.kube/config"`. This tier is consumed by all cluster operator home files (`home/bob.nix` today; future `home/<ecto-operator>.nix`).
- [X] T067 [P] [US4] Create `modules/home/workstation.nix`: `imports = [ ./base.nix ./ui.nix ./i3.nix ./polybar.nix ./dunst.nix ./dev.nix ./vscode.nix ]` (matches current `home/eaglerock.nix` import list exactly). These workstation-only modules MUST NOT be imported anywhere outside `workstation.nix`. NO `gpnr` alias here — it lives in `modules/home/base.nix` (universal; usable on cluster too).
- [X] T068 [P] [US4] Create `home/bob.nix`: `{ pkgs, ... }: { imports = [ ../modules/home/server.nix ]; home.username = "bob"; home.homeDirectory = "/home/bob"; home.stateVersion = "25.11"; programs.home-manager.enable = true; }`. HLC-specific home bits (e.g. cluster-themed shell greeting, kubeconfig paths specific to HLC) inline HERE — no `modules/home/hlc.nix` overlay file (Q17).
- [X] T069 [US4] Refactor `home/eaglerock.nix`: replace the current inline import list with `imports = [ ../modules/home/workstation.nix ]`. Preserve any eaglerock-specific overrides outside the imports block. Verify with `make local-dry` — must succeed with no evaluation errors.

### Wire Modules into Cluster + Workstation Scopes

- [X] T070 [US4] Refactor `modules/hosts/common.nix` as TOP-LEVEL CATCHALL (per D1; consumed by both workstations and cluster nodes) AND extract workstation-only bits into a new `modules/hosts/workstation.nix` (per C4/C5/C7).
  - **modules/hosts/common.nix** keeps universal content:
    1. `imports = [ ../shell/utilities.nix ../shell/common.nix ../users/operator.nix ];`
    2. nix.settings, time.timeZone, i18n.*, allowUnfree
    3. `services.openssh.enable = true` (single source of truth — cluster inherits)
    4. `programs.bash.interactiveShellInit = '' nr() {...} ndr() {...} '';` (universal: `nr`/`ndr` work on workstation AND cluster nodes)
    5. DROP the inline `environment.systemPackages` block (moved to `modules/shell/utilities.nix` per T060)
    6. DROP `programs.bash.promptInit` (silicon-specific PS1 — moves to workstation.nix)
    7. DROP `users.users.eaglerock = { ... }` inline block (per C5 — eaglerock specifics move to `hosts/silicon/configuration.nix`)
    8. DROP `virtualisation.docker.enable = true` (per C7 — moves to workstation.nix)
    9. DROP `boot.binfmt.emulatedSystems` (cluster nodes are aarch64 — can't emulate themselves; moves to workstation.nix)
  - **CREATE `modules/hosts/workstation.nix`** (new — workstation-tier system module):
    1. `imports = [ ./common.nix ];`
    2. `programs.bash.promptInit = '' ... '';` (silicon's Gruvbox PS1 — moved verbatim from common.nix)
    3. `virtualisation.docker.enable = true;`
    4. `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` (workstation cross-compiles cluster images)
    5. NOTE: this module does NOT set `system.operator.*` — eaglerock specifics live in the silicon host file.
  - **Update `hosts/silicon/configuration.nix`**:
    1. `imports = [ ../../modules/hosts/workstation.nix ../../modules/hosts/grub.nix ../../modules/hosts/desktop-ui.nix ../../modules/hosts/gaming.nix ../../modules/hardware/x1-carbon.nix ./hardware-configuration.nix ];` (swap `common.nix` for `workstation.nix`).
    2. `system.operator.name = "eaglerock";`
    3. `system.operator.pubkeys = operatorPubkeys;`
    4. `system.operator.description = "Peter Marks";`
    5. `system.operator.extraGroups = [ "wheel" "networkmanager" "docker" ];` (preserve existing eaglerock groups).
  - **Update `flake.nix` `nixosConfigurations.silicon.specialArgs`**: add `inherit operatorPubkeys;` (currently passed to cluster only).
  - Run `make local-dry` — must succeed; verify `users.users.eaglerock` materializes correctly via `system.operator`.
- [X] T071 [US4] Update `modules/cluster/common.nix`: (1) replace stub TODO comments with real imports — `imports = [ ../hosts/common.nix ./prompt.nix ./motd.nix ]` (cluster inherits shell tier + operator module + openssh + nix.settings + time/locale via `../hosts/common.nix`); (2) **remove** the inline `users.users.bob` block — produced by `modules/users/operator.nix` (T064) once `system.operator.name = "bob"` is set in the HLC scope (T072); (3) **remove** duplicate `services.openssh.enable = true` line (now set by catchall hosts/common.nix only); (4) **ADD cluster-only security policy here** (split from T064): `security.sudo.wheelNeedsPassword = false` with W-002 comment; `services.openssh.settings.PasswordAuthentication = false` and `KbdInteractiveAuthentication = false` with W-003 comment. Workstations skip these defaults by NOT importing `modules/cluster/common.nix`. (5) parameterize `system.activationScripts.cloneOperatorRepos` (per C6): replace literal `bobHome = "/home/bob"` with `operatorHome = "/home/${config.system.operator.name}"` and `chown bob:users` with `chown ${config.system.operator.name}:users`; wrap in `lib.mkIf (config.system.operator.name != null)`. (6) keep stub comment `# TODO Phase 7: import ../k8s/prereqs.nix` as placeholder for T090. Removing the inline bob user closes the W-001 inline-host pattern for `modules/cluster/common.nix`.
- [X] T072 [US4] Update `modules/cluster/hlc/default.nix`:
  1. **Remove** the stale `options.hlc.motd.banner` placeholder declaration (introduced as a Phase 4 stub in T018; superseded by `cluster.motd.banner` from T063).
  2. **Verify** `hlc.prompt.glyph` declaration in `options.nix` (created in T033) has the correct default: `"☁️🏔️☁️"` (emoji presentation, U+FE0F variation selectors — cloud + snow-capped mountain + cloud). Per-host fallback: set to `"☁⛰︎☁"` (text-presentation; U+FE0E selectors) for terminals where emoji renders double-width and breaks the prompt alignment. Do NOT re-declare this option in `default.nix` — it is already imported via `options.nix`.
  3. Set `cluster.motd.banner` to the exact HLC ASCII banner heredoc from `specs/001-nixos-rpi-cluster/post-mortem-26-04-29.md` (copy verbatim — character-for-character).
  4. Set `cluster.motd.quote = "Let's build just a happy little cloud.  ~ Bob Ross"`.
  5. Set `cluster.prompt.glyph = config.hlc.prompt.glyph` (wire HLC option into generic cluster mechanism).
  6. Set `system.operator.name = "bob"`, `system.operator.pubkeys = operatorPubkeys`, `system.operator.description = "HLC cluster operator"`.
  7. Wire home-manager for bob: `home-manager.users.bob = import ../../../home/bob.nix;` (match the integration pattern used for `eaglerock` in `flake.nix`).
- [X] T073 [US4] Run `make dry-run HOST=hlc-501` then `make build HOST=hlc-501` and `make local-dry` after T070–T072. Fix any evaluation errors before the canary deploy.

### Canary Deploy + Validation

- [X] T074 [US4] **[BUNDLE-CANARY]** Deploy operator-UX bundle to `hlc-501`: `make update-node HOST=hlc-501`. Then `make smoke-test HOST=hlc-501`. **On smoke-test fail**: `make rollback HOST=hlc-501`, then run `/speckit-debug` skill — comment-out imports in `modules/cluster/common.nix` one at a time, `make update-node HOST=hlc-501`, `make smoke-test HOST=hlc-501`, repeat to isolate the breaking module. Fix, then resume.
- [X] T075 [US4] Validate PS1 on `hlc-501`: `ssh bob@hlc-501` — observe unified two-line Gruvbox-colorized PS1 with `☁️ 🏔️ ☁️` glyph, teal box-drawing, gold user/hostname, green cwd, bright white `@`/`$`. Short hostname (`bob@hlc-501`) confirmed and accepted. Glyph spacing tuned (spaces between emoji). Set via `programs.bash.promptInit` to avoid NixOS default overwrite.
- [X] T076 [US4] Validate MOTD on `hlc-501`: `ssh bob@hlc-501` — observe Gruvbox-colorized HLC ASCII banner (gold borders, teal art, green "Happy Little Cloud", red "Bob Ross"), then `Cluster node: hlc-501.marks.dev` (teal label, bright white hostname), then colored Bob Ross quote. ANSI escapes via `builtins.fromJSON ''"\u001b"''` (single backslash). Verify hostname is dynamic (not hardcoded).
- [X] T077 [US4] Validate toolbox on `hlc-501`: `ssh bob@hlc-501 "which bat curl dig fd fzf git htop ip jq k9s kubectl helm lsof mdadm ncdu nc parted lspci rg rsync strace tcpdump tmux tree lsusb vim wget"` — all MUST resolve.
- [X] T078 [US4] Validate SSH hardening on `hlc-501`: `ssh -o PreferredAuthentications=password bob@hlc-501` MUST be rejected. Key-based login MUST still work.

#### Fleet Roll (serial; smoke-test gate per host; decom-set auto-skipped by Makefile)

- [X] T079 [US4] Roll bundle to `hlc-502`: `make update-node HOST=hlc-502` + `make smoke-test HOST=hlc-502`. On fail: `make rollback`; investigate node-local issue; fix before continuing.
- [ ] T080 [US4] Roll bundle to `hlc-503` (DECOM — defective USB controller; Makefile refuses; skip).
- [X] T081 [US4] Roll bundle to `hlc-504` + smoke-test.
- [X] T082 [US4] Roll bundle to `hlc-505` + smoke-test.
- [X] T083 [US4] Roll bundle to `hlc-506` + smoke-test.
- [ ] T084 [US4] Roll bundle to `hlc-507` (DECOM — Makefile refuses; skip and note).
- [X] T085 [US4] Roll bundle to `hlc-508` + smoke-test.
- [X] T086 [US4] Roll bundle to `hlc-401`: `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`. Verify MOTD/PS1/toolbox behavior on Pi 4.

### Silicon Wiring + Close Workarounds

- [X] T087 [US4] Apply changes to `silicon`: `make local-switch` (or `sudo nixos-rebuild switch --flake .#silicon`). Verify: toolbox commands available as `eaglerock@silicon`, no HLC MOTD in local terminal (workstation has no `cluster.motd.*` setting), workstation modules (i3, polybar) still functional, local PS1 unchanged (silicon does not import `modules/cluster/prompt.nix`).
- [X] T088 [US4] Close W-001 in `specs/WORKAROUNDS.md`: fill `Resolved: 2026-<date>`. Cluster modules reintroduced with canary + smoke-test gates per exit condition. Inline `users.users.bob` removed from `modules/cluster/common.nix`, and inline `users.users.eaglerock` removed from `modules/hosts/common.nix` (both now option-driven via `system.operator`); silicon-side eaglerock specifics relocated to `hosts/silicon/configuration.nix`.
- [X] T089 [US4] Close W-003 in `specs/WORKAROUNDS.md`: fill `Resolved: 2026-<date>`. `PasswordAuthentication = false` applied in `modules/cluster/common.nix` (T071), validated in T078. Commit. Tag `phase6-operator-ux`.

**Checkpoint**: US4 complete. SC-006 verified. W-001 and W-003 closed.

---

## Phase 7: User Story 5 — k3s Prerequisites (Priority: P5)

**Goal**: Every in-scope node has k3s, k9s, container runtime, kernel/sysctl prereqs installed. k3s service enabled but stopped; no cluster state on disk.

**Independent Test**: On any provisioned node: `k3s --version`, `k9s --version`, `k version --client` succeed. `systemctl is-enabled k3s` → `enabled`. `systemctl is-active k3s` → `inactive`. `/var/lib/rancher/k3s/` absent or empty.

- [X] T090 [US5] Create `modules/k8s/prereqs.nix`:
  - `services.k3s.enable = true` (installs binary + systemd unit)
  - `systemd.services.k3s.wantedBy = lib.mkForce [ ]` with comment: `# Enabled-but-stopped: follow-on cluster-bootstrap spec drops config and flips wantedBy back to [ "multi-user.target" ]`
  - `boot.kernelModules = [ "br_netfilter" "overlay" "ip_tables" ]`
  - `boot.kernel.sysctl = { "net.ipv4.ip_forward" = 1; "net.bridge.bridge-nf-call-iptables" = 1; "net.bridge.bridge-nf-call-ip6tables" = 1; }`
  - `systemd.enableCgroupAccounting = true` (cgroups v2)
  - Note: `k9s` and `kubectl` already provided by `modules/shell/utilities.nix` (T060) — do NOT duplicate in this module's systemPackages
- [X] T091 [US5] Update `modules/cluster/common.nix`: replace the `# TODO Phase 7: import ../k8s/prereqs.nix` stub with a real `import ../k8s/prereqs.nix`. Run `make dry-run HOST=hlc-501` — must succeed.
- [X] T092 [US5] Run `make build HOST=hlc-501` — full build must succeed after T090–T091.
- [X] T093 [US5] Apply k3s prereqs to `hlc-501`: `make update-node HOST=hlc-501` → `make smoke-test HOST=hlc-501` — green.
- [X] T094 [US5] Verify k3s prereqs on `hlc-501`:
  - `ssh bob@hlc-501 "k3s --version"` — prints version (non-zero = fail)
  - `ssh bob@hlc-501 "k9s --version"` — prints version
  - `ssh bob@hlc-501 "k version --client"` — alias resolves to `kubectl version --client`
  - `ssh bob@hlc-501 "systemctl is-enabled k3s"` → `enabled`
  - `ssh bob@hlc-501 "systemctl is-active k3s"` → `inactive`
  - `ssh bob@hlc-501 "sudo test ! -d /var/lib/rancher/k3s || echo EMPTY"` → no cluster state
- [X] T095 [US5] Verify kernel/sysctl prereqs on `hlc-501`:
  - `ssh bob@hlc-501 "lsmod | grep -E 'br_netfilter|overlay'"` — both loaded
  - `ssh bob@hlc-501 "sysctl net.ipv4.ip_forward"` → `1`
  - `ssh bob@hlc-501 "sysctl net.bridge.bridge-nf-call-iptables"` → `1`
  - `ssh bob@hlc-501 "cat /sys/fs/cgroup/cgroup.controllers"` — contains `memory cpu io` (cgroups v2 active)
- [X] T096 [US5] Roll k3s prereqs to `hlc-502..508` serially (hlc-503 and hlc-507 DECOM — Makefile refuses; skip): for each active node, `make update-node HOST=<host>` + `make smoke-test HOST=<host>`. Spot-check T094/T095 verifications on `hlc-504` (midpoint).
- [X] T097 [US5] Roll k3s prereqs to `hlc-401` (Pi 4): `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`. Verify same T094/T095 checks pass on Pi 4.
- [X] T098 [US5] Commit. Tag `phase7-k3s-prereqs`.

**Checkpoint**: US5 complete. SC-007 verified on all 9 work-set nodes.

---

## Phase 8: Polish & Cross-Cutting Validation

**Purpose**: Final acceptance criteria validation, documentation cleanup, spec close-out.

- [ ] T099 [P] **DEFERRED**: Validate SC-001 — requires full cold provision (physical re-flash). Deferred pending provision troubleshooting. Operator wall-clock time excluding raw `dd` flash time MUST be ≤ 30 minutes.
- [X] T100 [P] Validate SC-002: from a clean checkout (`git clone` or `git clean -fdx`), run `make dry-run HOST=<host>` for all 12 hosts. All MUST succeed with no manual edits. **Validated 2026-05-17**: 12/12 dry-run green.
- [X] T101 [P] Validate SC-004: confirm `hlc-401` (Pi 4) and `hlc-501` (Pi 5) both boot, provision, and operate using the same `make` targets. No Pi-family-specific tooling required. **Validated by Phase 5 provisioning history**.
- [X] T102 Validate SC-007 completeness: run T094/T095 checks on `hlc-401`, `hlc-501`, and two random Pi 5 nodes. All MUST pass. **Validated 2026-05-17**: hlc-401, hlc-501, hlc-504 all pass. `k8s-health-check` script deployed fleet-wide.
- [X] T103 Review `specs/WORKAROUNDS.md`: W-001 Resolved ✅, W-003 Resolved ✅, W-004 Resolved ✅ (no-op: bootstrap-permanent PAM fix), W-002 Open (secrets management → feature 002). W-010/W-011/W-012/W-013 open, all tracked. W-001 and W-003 moved from Outstanding to Resolved section. **Validated 2026-05-17**.
- [X] T104 Update `quickstart.md` with any runtime-discovered deviations. Closing section updated to reflect actual fleet state (7 active, 2 DECOM), resolved/open workaround entries. **Updated 2026-05-17**.
- [X] T105 Update `research.md` open follow-ups: marked as resolved — R-001 ✅ (nvmd confirmed working), R-003 ✅ (wantedBy override sufficient), R-004 ✅ (NVMe /dev/nvme0n1, USB by-path confirmed), R-005 ✅ (BOOT_ORDER 0xf14 verified), R-011 ✅ (config.txt option path: raspberry-pi.config), R-013 ✅ (custom systemd one-shot with marker file), R-016 ✅ (two-phase provision validated). **Updated 2026-05-17**.
- [ ] T106 Final commit: `git commit -m "Phase 8: spec close-out — all acceptance criteria validated"`. Push branch and open PR for review.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup (T001–T008)**: ✅ Complete. No dependencies.
- **Phase 2 Foundational**: ✅ Complete (subsumed by Phase 1).
- **Phase 3 US1 (T009–T016)**: Depends on Phase 1. Independent of other user stories.
- **Phase 4 US2 (T017–T027)**: Depends on Phase 1. Independent of US1 (structural only; no physical hardware required).
- **Phase 5 US3 (T028–T059)**: Depends on US1 (working SD baseline for nixos-anywhere) AND US2 (per-host configs must exist). Includes `update-node` and `rollback` targets (needed by `provision-stage3`).
- **Phase 6 US4 (T060–T089)**: Depends on US3 (nodes provisioned to accept `update-node`). `update-node`/`rollback` already exist from Phase 5.
- **Phase 7 US5 (T090–T098)**: Depends on US3 (provisioned) AND US4 (`cluster/common.nix` wired; stub import already placed in T071).
- **Phase 8 Polish (T099–T106)**: Depends on all user stories complete.

### Dependency Graph

```text
US1 (T009-T016) ──────────────────────────────────► US3 (T028-T059)
US2 (T017-T027) ──────────────────────────────────►     └──► US4 (T060-T089)
                                                               └──► US5 (T090-T098)
                                                                     └──► Polish (T099-T106)
```

### Per-Phase Canary Cadence

| Phase | Canary | Fleet After |
| ----- | ------ | ----------- |
| US1 | hlc-501 (SD flash + smoke-test) | None (single-host) |
| US2 | All 12 via dry-run only | N/A (no live nodes) |
| US3 | hlc-501 (two-phase provision + recovery test) | hlc-502..508 then hlc-401 |
| US4 | hlc-501 (bundle update-node + smoke-test) | hlc-502..508 then hlc-401 + silicon |
| US5 | hlc-501 (update-node + k3s checks) | hlc-502..508 then hlc-401 |

### Parallel Opportunities Within Phases

- **US2 (Phase 4)**: T019+T020 (hardware stubs), T021+T022+T023 (host files) — all parallel.
- **US3 (Phase 5)**: T028+T029 (disko schemas), T030+T031 (hardware expansion), T033+T034 (options.nix + provision.nix), T049 (Pi 5 device IDs) — parallel.
- **US4 (Phase 6)**: T060 through T068 (module creation) — all parallel before T069 wiring.
- **Phase 8**: T099, T100, T101 — parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 3 US1 (T009–T016)
2. **STOP and VALIDATE**: SD baseline boots, cache invariant confirmed, smoke-test green
3. Proceed to US2+US3 only after US1 gate passes

### Incremental Delivery

1. US1 → SD baseline validated
2. US2 → All 12 host configs evaluate
3. US3 → All 9 nodes provisioned via two-phase flow (cluster has durable storage)
4. US4 → Operator UX live (W-001 + W-003 closed)
5. US5 → k3s prereqs live (follow-on spec can wire cluster immediately)

### Rollback at Any Phase

Every post-provisioning phase: `make rollback HOST=<host>` reverts to prior NixOS generation. SD re-flash resets pre-provisioning phases. SD recovery environment (remove USB drives) is last-resort for all provisioned nodes.

---

## Notes

- `[P]` = different files, no blocking dependencies
- `[Story]` label maps to spec user story
- `[X]` = task complete
- Smoke-test: no PTY (`-t`), remove known_hosts for both IP + hostname, test both non-PTY SSH
- Decom-set hosts (`hlc-402..404`): dry-run only; flash/provision/update-node against them = Constitution violation
- Commit after each phase gate (tagged) for `git bisect` recovery
- Constitution VIII: if any step produces unexpected state, state the conflict explicitly — do not silently rewrite the working theory
