# Tasks: NixOS RPi Cluster Foundation (v2)

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Test tasks are NOT included. This is a NixOS configuration repo; the verification model is `dry-run` → `build` → `update-node` (one host) → `smoke-test` (Constitution §"Safety & Change Management"), not unit/integration tests. Operator manually canaries by running `update-node` on the canary node, verifying with `smoke-test`, then proceeding to the rest of the work-set (or `make rollback` if smoke-test fails). **Canary scope** = the change set being deployed; per Constitution v1.3.3 §IV both per-module and phase-bundle scopes are admissible (bundle path additionally requires `/speckit-debug` on smoke-test fail to bisect to the breaking module). Automated single-command canary is out of scope for this spec.

**Smoke-test definition** (updated 2026-04-30): `make smoke-test HOST=<host>` removes SSH host key entries from `~/.ssh/known_hosts` for both the node IP and hostname, then verifies non-PTY SSH login succeeds on both IP and hostname (no `-t` flag; PTY mode caused Pi login hangs during testing; command: `uname -a`).

**Phase mapping** (tasks.md vs plan.md phase numbers differ):

| tasks.md Phase | plan.md Phase | Content |
|----------------|---------------|---------|
| Phase 1 Setup | Phases 0+1 | Baseline reset + nvmd upstream swap |
| Phase 2 Foundational | (empty) | Subsumed by Phase 1 |
| Phase 3 US1 | Phase 2 | SD bootstrap rebuild |
| Phase 4 US2 | Phase 3 | Per-host scaffolding |
| Phase 5 US3 | Phase 4 | Disko + provisioning |
| Phase 6 US4 | Phase 5 | Operator UX |
| Phase 7 US5 | Phase 6 | k3s prerequisites |
| Phase 8 Polish | (post-spec) | Final validation + close-out |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1..US5)
- **[X]**: Task complete

---

## Phase 1: Setup (Plan Phases 0+1 — COMPLETE)

**Purpose**: Baseline reset to `main` running-code state + nvmd upstream swap + foundational Makefile targets.

- [X] T001 Tag pre-reset snapshot: `git tag pre-reset-2026-04-29`
- [X] T002 Restore main running code via `git checkout main -- flake.nix flake.lock Makefile hosts/silicon hosts/hlc-501 home/eaglerock.nix modules/home modules/hosts modules/hardware/x1-carbon.nix`
- [X] T003 Remove failed-attempt-only files via `git rm -r hosts/hlc-{401,402,403,404,502,503,504,505,506,507,508} modules/cluster modules/motd modules/shell modules/users modules/hardware/rpi4.nix modules/hardware/rpi5.nix` and `git rm -f hlc-output.txt lshw-output.txt`
- [X] T004 Commit baseline reset: `git commit -m "Phase 0: baseline reset — running code to main, context kept"` then `git tag phase0-baseline-reset`
- [X] T005 Update `flake.nix`: remove `raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix"`, add `nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi"`, re-add `operatorPubkey` constant and `mkHlcNode` helper, add `disko`/`nixos-anywhere`/`sops-nix` inputs
- [X] T006 Run `nix flake update nixos-raspberrypi disko nixos-anywhere sops-nix` (input-scoped; do NOT run bare `nix flake update` to avoid bumping nixpkgs/home-manager on the same commit). Commit `flake.nix` and `flake.lock` together.
- [X] T007 Add Phase 2 Foundational Makefile targets to `Makefile`: `dry-run HOST=<host>` (gibson: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`; silicon: `sudo nixos-rebuild dry-run --flake .#<host>`), `build HOST=<host>` (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L`), `smoke-test HOST=<host>` (remove known_hosts for IP + hostname, then `ssh bob@<IP> uname -a` and `ssh bob@<HOST> uname -a`, no `-t`), `ip HOST=<host>` (pure shell HOST→IP derivation per HLC convention: `hlc-VNN` → `10.23.50.<V*10+NN>`)
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

- [ ] T009 [US1] Create `modules/sd/recovery-utils.nix`: define `environment.systemPackages` list — alphabetically sorted, one-line inline comment per package: `curl` (HTTP fetches), `dmidecode` (hardware info), `dnsutils` (DNS diagnostics; provides `dig`/`nslookup`), `e2fsprogs` (ext4 filesystem tools), `git` (repo access), `gptfdisk` (GPT partition manipulation; provides `sgdisk`), `htop` (process monitor), `iproute2` (ip command), `lsblk` (from `util-linux`; block device lister), `mdadm` (RAID management), `parted` (partition editor), `pciutils` (PCIe device info; provides `lspci`), `tmux` (terminal multiplexer), `usbutils` (USB device info; provides `lsusb`), `vim` (editor), `xfsprogs` (XFS filesystem tools). Note: some packages overlap with `modules/shell/utilities.nix` (curl, dnsutils, htop, mdadm, parted, tmux, usbutils, vim) — intentional per FR-003; SD bootstrap is an isolated closure that must not import the cluster toolbox module.
- [ ] T010 [US1] Create `modules/sd/bootstrap.nix`: `imports = [ ./recovery-utils.nix ]`; define `users.users.bob = { isNormalUser = true; extraGroups = [ "wheel" ]; openssh.authorizedKeys.keys = [ operatorPubkey ]; }`; set `services.openssh = { enable = true; settings.PasswordAuthentication = false; settings.KbdInteractiveAuthentication = false; }`; set `networking.useDHCP = true`; set `networking.hostName = "hlc-sd-bootstrap"`. Do NOT import any per-host service modules, `modules/cluster/*`, `modules/hardware/*`, or `modules/k8s/*`.
- [ ] T011 [US1] Update `flake.nix` SD image build path: ensure the `sdImage` (or `build-image`) derivation's NixOS module list imports only `modules/sd/bootstrap.nix`. Per-host service modules, cluster scope, hardware scope, and k8s scope MUST NOT appear in the SD image closure. Verify with `nix eval .#<sdImageAttrPath> --dry-run` (or equivalent `nix build --dry-run` for the SD image output).
- [ ] T012 [US1] Add `REBUILD=1` opt-in to `make build-image` in `Makefile`: when `REBUILD=1` is set, append `--rebuild` to the underlying `nix build` invocation. Default behavior (no flag) relies on Nix content-addressing (FR-004).
- [ ] T013 [US1] Validate cache invariant: (a) run `make build-image HOST=hlc-501` and record the output store path; (b) change a comment in `modules/sd/bootstrap.nix`; (c) run `make build-image HOST=hlc-501` again without `REBUILD=1`; (d) confirm the output store path changed. This validates FR-004 — the derivation closure correctly depends on `modules/sd/bootstrap.nix`.
- [ ] T014 [US1] Flash rebuilt SD: `make flash-image HOST=hlc-501 DEV=/dev/sdX`. Insert into `hlc-501`, power on, wait ~5 minutes, run `make smoke-test HOST=hlc-501` — must be green.
- [ ] T015 [US1] Validate recovery utils on `hlc-501`: `ssh bob@hlc-501 "which mdadm parted vim git curl"` — all MUST resolve. Confirm `uname -a` reports `NixOS aarch64`.
- [ ] T016 [US1] Commit with message describing SD bootstrap separation and cache-invariant fix. Tag `phase2-sd-bootstrap`.

**Checkpoint**: US1 complete. SD bootstrap boots, cache invariant verified, smoke-test green.

---

## Phase 4: User Story 2 — Modular Per-Host Configuration (Priority: P2)

**Goal**: All 12 host configurations (`hlc-401..404`, `hlc-501..508`) evaluate via `make dry-run` from a clean checkout. Three-scope module layering in place.

**Independent Test**: From a clean checkout, `make dry-run HOST=hlc-<N>` succeeds for all 12 hosts. Adding a stub `hosts/hlc-509/configuration.nix` + flake entry requires no other edits.

- [ ] T017 Create `modules/cluster/common.nix` structural skeleton: set `networking.domain = "marks.dev"`; set `services.openssh.enable = true`; set `users.mutableUsers = false`. Add stub import comments `# TODO Phase 6: imports = [ ../shell/utilities.nix ../shell/common.nix ../shell/prompt.nix ../motd/default.nix ../users/operator.nix ]` so the wiring point is explicit. Do NOT import stub-free module paths that don't exist yet.
- [ ] T018 Create `modules/cluster/hlc/default.nix`: import `modules/cluster/common.nix`; set `networking.domain = "marks.dev"` — NixOS computes `config.networking.fqdn` as `"${hostName}.${domain}"` automatically; do NOT attempt to assign `networking.fqdn` directly (it is a read-only derived option and will fail evaluation); add placeholder `hlc.motd.banner = ""` option (populated Phase 6).
- [ ] T019 [P] Create `modules/hardware/rpi4.nix` stub: set `nixpkgs.hostPlatform = "aarch64-linux"`; import nvmd's RPi 4 hardware module (check `github:nvmd/nixos-raspberrypi` README or `flake.nix` outputs for the Pi 4 / bcm2711 module path — likely `nixosModules.raspberry-pi-4` or similar). Add stub comments `# TODO Phase 5: config.txt + EEPROM + thermal`.
- [ ] T020 [P] Create `modules/hardware/rpi5.nix` stub: same structure as rpi4 but for Pi 5 / bcm2712, importing nvmd's RPi 5 hardware module. Add stub comments `# TODO Phase 5: config.txt + EEPROM + NVMe + thermal`.
- [ ] T021 [P] Create per-host files for Pi 5 work-set: for each of `hlc-501` through `hlc-508`, create `hosts/hlc-5NN/configuration.nix` with `imports = [ ../../modules/cluster/hlc/default.nix ../../modules/hardware/rpi5.nix ]`, `networking.hostName = "hlc-5NN"`, and `hlc.disko.usbDevice0 = "PLACEHOLDER"`; `hlc.disko.usbDevice1 = "PLACEHOLDER"`; `hlc.disko.nvmeDevice = "PLACEHOLDER"` (real `/dev/disk/by-id/` paths filled in Phase 5 before provisioning).
- [ ] T022 Create `hosts/hlc-401/configuration.nix`: `imports = [ ../../modules/cluster/hlc/default.nix ../../modules/hardware/rpi4.nix ]`, `networking.hostName = "hlc-401"`, USB device placeholders, `hlc.disko.nvmeDevice = null`.
- [ ] T023 [P] Create deferred Pi 4 host files for `hlc-402`, `hlc-403`, `hlc-404`: same structure as hlc-401. Add comment in each: `# DEFERRED: config-only per Constitution cluster-topology; do NOT flash or run nixos-rebuild switch`.
- [ ] T024 Update `flake.nix` `nixosConfigurations` to include all 12 hosts (`hlc-401..404`, `hlc-501..508`). Each entry: `lib.nixosSystem { system = "aarch64-linux"; modules = [ hosts/<hostname>/configuration.nix ]; }` (plus home-manager if already wired at the flake level).
- [ ] T025 Run `make dry-run` for all 12 hosts and confirm each succeeds: `make dry-run HOST=hlc-401`, `make dry-run HOST=hlc-402`, `make dry-run HOST=hlc-403`, `make dry-run HOST=hlc-404`, `make dry-run HOST=hlc-501` through `make dry-run HOST=hlc-508`. Fix any evaluation errors before proceeding.
- [ ] T026 SC-003 testability: create `hosts/hlc-509/configuration.nix` (copy of hlc-501 with `networking.hostName = "hlc-509"`) and add `hlc-509` entry to `flake.nix`. Run `make dry-run HOST=hlc-509` — must succeed. Confirm only 2 file changes were required. Remove `hosts/hlc-509/` and revert the flake entry after verification.
- [ ] T027 Commit with message describing layered scaffolding and all-12 dry-run validation. Tag `phase3-scaffolding`.

**Checkpoint**: US2 complete. All 12 hosts evaluate from clean checkout. SC-002 and SC-003 verified.

---

## Phase 5: User Story 3 — Full-Disk Provisioning (Priority: P3)

**Goal**: Provisioning workflow installs full per-host NixOS onto USB-RAID root + NVMe data volume. EEPROM boot order locked to USB-first, SD-fallback. Recovery scenario verified.

**Independent Test**: Provision `hlc-501` end-to-end — nixos-anywhere runs from gibson, Pi reboots into USB array root, mounts correct. Detach USB drives, power-cycle — SD recovery boots with `mdadm` available, smoke-test green. Re-attach, normal boot. Repeat on `hlc-401` (Pi 4, no NVMe; `/srv/ssd` absent without error).

- [ ] T028 [P] Create `disko/rpi5.nix`: define `disko.devices` for Pi 5 layout — (a) SD card `vfat` for `/boot`; (b) `mdadm` RAID1 across `config.hlc.disko.usbDevice0` and `usbDevice1`, ext4 for `/` and ext4 for `/srv/usb`; (c) `config.hlc.disko.nvmeDevice` xfs for `/srv/ssd`. Use `/dev/disk/by-id/` paths. Default mode: `disko` (not `disko-destroy`) for FR-013 idempotency. Expose `hlc.disko.{usbDevice0,usbDevice1,nvmeDevice}` as typed NixOS options.
- [ ] T029 [P] Create `disko/rpi4.nix`: same as `disko/rpi5.nix` but without the NVMe device block. `/srv/ssd` mount point MUST NOT be defined. `hlc.disko.nvmeDevice` option present but nullable; Pi 4 provisioning succeeds when it is `null`.
- [ ] T030 Expand `modules/hardware/rpi5.nix` with full config.txt profile (FR-025, R-011): `gpu_mem = 16`, `dtparam = audio=off`, `dtoverlay = disable-bt`, `disable_splash = 1`, `boot_delay = 0`, `dtparam = nvme`. Verify the exact NixOS option path from nvmd module surface (check nvmd README or `nixosModules.raspberry-pi-5` option set). Add Pi 5 thermal: stock clocks 2.4 GHz, kernel-controlled fan curve, no overclock (R-012, FR-027).
- [ ] T031 Expand `modules/hardware/rpi4.nix` with config.txt profile (same headless set minus `dtparam=nvme`). Add Pi 4 thermal: `over_voltage = 2`, `arm_freq = 1750` (modest overclock, passive heatsink validated; R-012, FR-027).
- [ ] T032 Create `modules/hardware/rpi-eeprom.nix` (FR-026, R-013): `systemd.services.rpi-eeprom-config` one-shot service that applies EEPROM config — `BOOT_ORDER=0xf14`, `BOOT_UART=1` (universal); `WAKE_ON_GPIO=0`, `POWER_OFF_ON_HALT=1` (Pi 5 only; guard with `pkgs.lib.optionalString (config.hardware.raspberry-pi.variant == "rpi5") "..."`). Gate idempotency with marker file `/boot/.eeprom-configured` — service is a no-op if marker exists. `serviceConfig.Type = "oneshot"`; `serviceConfig.RemainAfterExit = true`. Import this module from both `modules/hardware/rpi4.nix` and `modules/hardware/rpi5.nix`.
- [ ] T033 Add `make provision HOST=<host> [IP=<ip>]` to `Makefile`: resolves IP via HLC convention unless overridden; runs `nixos-anywhere --flake .#<host> --target-host root@<IP> --disko-mode disko`; refuses decom-set hosts (`hlc-402..404`) with message: `"ERROR: hlc-40[234] is decommissioned-set; provision blocked per Constitution cluster-topology rules"`.
- [ ] T034 Run `make dry-run HOST=hlc-501` and `make build HOST=hlc-501` after T028–T033 additions. Both must succeed. Fix any evaluation errors.
- [ ] T035 Fill real device IDs for `hlc-501`: SSH to SD baseline (`ssh bob@hlc-501`), run `ls -la /dev/disk/by-id/ | grep -v '\-part'` to find USB and NVMe IDs. Update `hosts/hlc-501/configuration.nix` replacing `"PLACEHOLDER"` values with real `/dev/disk/by-id/...` strings.
- [ ] T036 Provision `hlc-501`: `make provision HOST=hlc-501`. After reboot, SSH as `bob@hlc-501` and verify: `df -h /` shows mdadm array, `df -h /srv/ssd` shows NVMe, `df -h /srv/usb` shows array mount. Run `make smoke-test HOST=hlc-501` — green.
- [ ] T037 Verify RAID health: `ssh bob@hlc-501 "sudo mdadm --detail /dev/md0"` — both USB devices show as active/in-sync.
- [ ] T038 Recovery test (FR-011, SC-005): power down `hlc-501`; physically detach both USB drives; power on. Wait ~3 min. Run `make smoke-test HOST=hlc-501` — green (SD boots). SSH in; run `sudo mdadm --examine /dev/sda` (or visible device) — confirms recovery utilities available. Re-attach USB drives; power cycle; `make smoke-test HOST=hlc-501` — green (USB array boot).
- [ ] T039 Idempotency test (FR-013): re-run `make provision HOST=hlc-501` on the already-provisioned node. MUST either be a no-op or refuse with a documented message. MUST NOT silently corrupt the array. Document the observed behavior in a comment in `contracts/makefile-targets.md` if it differs from the specified behavior. Also validate retry-resilience (spec edge case): if `nixos-anywhere` loses SSH mid-run, the SD baseline must remain bootable so the operator can retry. Simulate by interrupting a provision mid-flight (Ctrl-C after partitioning begins); then run `make smoke-test HOST=hlc-501` against the SD IP — green means SD is still intact. Re-attach and re-provision to restore the USB array.
- [ ] T040 [P] Fill real device IDs for `hlc-502` through `hlc-508`: SSH each node's SD baseline, run the `ls -la /dev/disk/by-id/` command, update `hosts/hlc-5NN/configuration.nix`. (Can be done in parallel across nodes.)
- [ ] T041 Provision `hlc-502`: `make provision HOST=hlc-502`. Run `make smoke-test HOST=hlc-502`. Verify mounts.
- [ ] T042 Provision `hlc-503`: `make provision HOST=hlc-503`. Run `make smoke-test HOST=hlc-503`.
- [ ] T043 Provision `hlc-504`: `make provision HOST=hlc-504`. Run `make smoke-test HOST=hlc-504`.
- [ ] T044 Provision `hlc-505`: `make provision HOST=hlc-505`. Run `make smoke-test HOST=hlc-505`.
- [ ] T045 Provision `hlc-506`: `make provision HOST=hlc-506`. Run `make smoke-test HOST=hlc-506`.
- [ ] T046 Provision `hlc-507`: `make provision HOST=hlc-507`. Run `make smoke-test HOST=hlc-507`.
- [ ] T047 Provision `hlc-508`: `make provision HOST=hlc-508`. Run `make smoke-test HOST=hlc-508`.
- [ ] T048 Fill real device IDs for `hlc-401` in `hosts/hlc-401/configuration.nix`. Pi 4: USB drives only; `hlc.disko.nvmeDevice = null`.
- [ ] T049 Provision `hlc-401` (Pi 4): `make provision HOST=hlc-401`. After reboot, verify `/srv/ssd` does NOT exist (absent without error, FR-010). Verify `/` on mdadm array, `/srv/usb` mounted. Run `make smoke-test HOST=hlc-401` — green.
- [ ] T050 Commit all device-ID updates and provisioning-validated configs. Tag `phase4-provisioned`.

**Checkpoint**: US3 complete. All 9 work-set nodes provisioned. SC-005 verified.

---

## Phase 6: User Story 4 — Operator UX (Priority: P4)

**Goal**: HLC MOTD, two-form PS1, sysadmin toolbox, modular home-manager, SSH hardening — live across all work-set nodes. W-001 and W-003 closed.

**Independent Test**: SSH as `bob@hlc-501` → HLC MOTD (banner + `Cluster node: hlc-501.marks.dev` + Bob Ross quote), remote PS1 (`┌─╸bob@hlc-501.marks.dev ☁⛰︎☁ [~]` / `└──╸$`), all toolbox commands on `$PATH`. SSH as `eaglerock@silicon` → same toolbox, no HLC MOTD, workstation PS1 unaffected.

**Per-phase cadence (bundle)**: Tasks T053–T066 (all module creation and wiring) execute as one batch before a single canary deploy at T067. Smoke-test green → fleet roll (T068–T075). On smoke-test fail at T067: `make rollback HOST=hlc-501`, then `/speckit-debug` bisect (comment-out new imports in `modules/cluster/common.nix` one at a time, re-canary, smoke-test) to isolate the breaking module.

### Add Phase 6 Makefile Targets

- [ ] T051 Add `make update-node HOST=<host> [IP=<ip>]` to `Makefile`: wraps `sudo nixos-rebuild switch --flake .#<host> --target-host bob@<IP> --use-remote-sudo`. Derives IP from HOST per HLC convention unless `IP=` is provided. Refuses decom-set hosts with error message.
- [ ] T052 Add `make rollback HOST=<host> [IP=<ip>]` to `Makefile`: wraps `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<IP> --use-remote-sudo`. Same IP-derivation and decom-set guard.

### Create US4 Modules (Bundle — all before canary)

- [ ] T053 [P] [US4] Create `modules/shell/utilities.nix`: `environment.systemPackages = with pkgs; [` alphabetically sorted list with one-line inline comments `]`. Include: `bat` (colorized cat), `curl` (HTTP client), `dnsutils` (dig/nslookup), `fd` (fast find), `fzf` (fuzzy finder), `git` (VCS), `htop` (process monitor), `iproute2` (ip/ss commands), `jq` (JSON processor), `lsof` (open file list), `mdadm` (RAID management), `ncdu` (disk usage navigator), `netcat` (nc; TCP/UDP tool), `parted` (partition editor), `pciutils` (lspci), `ripgrep` (fast grep; provides `rg`), `rsync` (file sync), `strace` (syscall tracer), `tcpdump` (packet capture), `tmux` (terminal multiplexer), `tree` (directory listing), `usbutils` (lsusb), `vim` (editor), `wget` (HTTP downloader).
- [ ] T054 [P] [US4] Create `modules/shell/common.nix`: set `programs.bash.enable = true`; `users.defaultUserShell = pkgs.bash`; define `programs.bash.shellAliases = { ll = "ls -la"; la = "ls -A"; ".." = "cd .."; "..." = "cd ../.."; k = "kubectl"; }`; set `environment.variables.EDITOR = "vim"`.
- [ ] T055 [P] [US4] Create `modules/shell/prompt.nix`: generate `/etc/profile.d/hlc-prompt.sh` via `environment.etc."profile.d/hlc-prompt.sh".text`. The script sets `PS1` based on `$SSH_CONNECTION`:
  - **Remote form** (SSH; `$SSH_CONNECTION` non-empty): `PS1='\e[1m┌─╸\e[0m\u@\H ☁⛰︎☁ [\w]\n\e[1m└──╸\e[0m\$ '`. No `\033[...m` color codes. Bold (`\e[1m`) on box-drawing glyphs only. `\H` expands to FQDN **only if** the kernel hostname is fully-qualified — verify this at T067 by checking `hostname -f` on the node; if `\H` returns only the short name (meaning the kernel hostname is unqualified despite `networking.domain` being set), substitute `$(hostname -f)` via a shell subshell in the PS1 string instead.
  - **Local form** (`$SSH_CONNECTION` empty): same color escapes as silicon's existing prompt but with `☁⛰︎☁` substituting `////` at the end: `PS1='\[<gruvbox-path-color>\]\w\[\033[0m\] ☁⛰︎☁ \$ '` (read actual color codes from `modules/home/colors.nix` or silicon's existing bashrc; use the same escape sequence). Expose `hlc.prompt.mountainGlyph` NixOS option (string, default = `"⛰︎"`; set to `"▲"` for terminals that render the glyph as double-width emoji despite the variation selector).
- [ ] T056 [P] [US4] Create `modules/motd/default.nix`: define options `hlc.motd.banner` (string) and `hlc.motd.quote` (string, default = `"Let's build just a happy little cloud.  ~ Bob Ross"`). Generate `environment.etc."motd".text = "${config.hlc.motd.banner}\nCluster node: ${config.networking.fqdn}\n${config.hlc.motd.quote}\n"`. Set `services.openssh.settings.PrintMotd = true` (or the NixOS-appropriate option). Look up the exact HLC ASCII banner text from `specs/001-nixos-rpi-cluster/post-mortem-26-04-29.md` and set as the default for `hlc.motd.banner` in `modules/cluster/hlc/default.nix` (not here — keep this module generic).
- [ ] T057 [P] [US4] Create `modules/users/operator.nix`: define `users.users.bob = { isNormalUser = true; extraGroups = [ "wheel" ]; openssh.authorizedKeys.keys = [ operatorPubkey ]; description = "HLC cluster operator"; shell = pkgs.bash; }`. Set `security.sudo.wheelNeedsPassword = false` with comment `# W-002: passwordless wheel during cluster transition; remove once sops-nix secrets management lands (feature 002)`. Define SSH hardening: `services.openssh.settings.PasswordAuthentication = false; services.openssh.settings.KbdInteractiveAuthentication = false;` with comment `# W-003 closed: key-only SSH enforced post-provisioning`.
- [ ] T058 [P] [US4] Create `modules/home/base.nix`: home-manager module with cross-cutting defaults — `programs.neovim = { enable = true; defaultEditor = true; viAlias = true; vimAlias = true; }`, `programs.git = { enable = true; }`, any other defaults shared between `bob` and `eaglerock` that currently live scattered in per-user files.
- [ ] T059 [P] [US4] Create `modules/home/server.nix`: `imports = [ ./base.nix ]`; add server-only config — `programs.tmux = { enable = true; shortcut = "a"; historyLimit = 50000; clock24 = true; }`, `home.sessionVariables.KUBECONFIG = "$HOME/.kube/config"`.
- [ ] T060 [P] [US4] Create `modules/home/workstation.nix`: `imports = [ ./base.nix ./i3.nix ./polybar.nix ./dunst.nix ./ui.nix ./vscode.nix ]` (adjust list to match modules that actually exist in `modules/home/`). These workstation-only modules MUST NOT be imported anywhere outside `workstation.nix`.
- [ ] T061 [P] [US4] Create `home/bob.nix`: `{ pkgs, ... }: { imports = [ ../modules/home/server.nix ]; home.username = "bob"; home.homeDirectory = "/home/bob"; home.stateVersion = "25.11"; }`.
- [ ] T062 [US4] Update `home/eaglerock.nix`: replace any direct inline imports of modules now handled by `modules/home/workstation.nix` with a single `imports = [ ../modules/home/workstation.nix ]`. Preserve any eaglerock-specific overrides. Run `make silicon-dry` — must succeed with no evaluation errors.

### Wire Modules into Cluster Scope

- [ ] T063 [US4] Update `modules/cluster/common.nix`: replace stub TODO comments with real imports — `imports = [ ../shell/utilities.nix ../shell/common.nix ../shell/prompt.nix ../motd/default.nix ../users/operator.nix ]`. The `../k8s/prereqs.nix` import will be added in T084 (Phase 7); add a stub comment `# TODO Phase 7: import ../k8s/prereqs.nix` here as placeholder.
- [ ] T064 [US4] Update `modules/cluster/hlc/default.nix`: set `hlc.motd.banner` to the exact HLC ASCII banner text from `specs/001-nixos-rpi-cluster/post-mortem-26-04-29.md` (copy verbatim — verify character-for-character). Wire home-manager for `bob`: integrate `home-manager.users.bob = import ../../home/bob.nix;` (match the integration pattern used for `eaglerock` in `hosts/silicon/` or the top-level flake — check existing home-manager wiring to get the exact attribute path right).
- [ ] T065 [US4] Run `make dry-run HOST=hlc-501` then `make build HOST=hlc-501` after T063–T064. Fix any evaluation errors before the canary deploy.

### Canary Deploy + Validation

- [ ] T066 [US4] **[BUNDLE-CANARY]** Deploy operator-UX bundle to `hlc-501`: `make update-node HOST=hlc-501`. Then `make smoke-test HOST=hlc-501`. **On smoke-test fail**: `make rollback HOST=hlc-501`, then run `/speckit-debug` skill — comment-out imports in `modules/cluster/common.nix` one at a time, `make update-node HOST=hlc-501`, `make smoke-test HOST=hlc-501`, repeat to isolate the breaking module. Fix, then resume.
- [ ] T067 [US4] Validate PS1 on `hlc-501`: (a) `ssh bob@hlc-501` from `TERM=xterm-256color` terminal — observe two-line box-drawing remote PS1 with `☁⛰︎☁`; (b) `ssh -o "SendEnv TERM" bob@hlc-501` with `TERM=xterm` — remote PS1 renders without color artifacts. Confirm `⛰︎` renders as text (not double-width emoji). If emoji rendering observed, set `hlc.prompt.mountainGlyph = "▲"` in `hosts/hlc-501/configuration.nix`, rebuild, redeploy.
- [ ] T068 [US4] Validate MOTD on `hlc-501`: `ssh bob@hlc-501` — observe HLC ASCII banner, then `Cluster node: hlc-501.marks.dev`, then Bob Ross quote. Verify hostname is dynamic (not hardcoded).
- [ ] T069 [US4] Validate toolbox on `hlc-501`: `ssh bob@hlc-501 "which bat curl dig fd fzf git htop ip jq lsof mdadm ncdu nc parted lspci rg rsync strace tcpdump tmux tree lsusb vim wget"` — all MUST resolve.
- [ ] T070 [US4] Validate SSH hardening on `hlc-501`: `ssh -o PreferredAuthentications=password bob@hlc-501` MUST be rejected. Key-based login MUST still work.

#### Fleet Roll (serial; smoke-test gate per host)

- [ ] T071 [US4] Roll bundle to `hlc-502`: `make update-node HOST=hlc-502` + `make smoke-test HOST=hlc-502`. On fail: `make rollback`; investigate node-local issue; fix before continuing.
- [ ] T072 [US4] Roll bundle to `hlc-503` + smoke-test.
- [ ] T073 [US4] Roll bundle to `hlc-504` + smoke-test.
- [ ] T074 [US4] Roll bundle to `hlc-505` + smoke-test.
- [ ] T075 [US4] Roll bundle to `hlc-506` + smoke-test.
- [ ] T076 [US4] Roll bundle to `hlc-507` + smoke-test.
- [ ] T077 [US4] Roll bundle to `hlc-508` + smoke-test.
- [ ] T078 [US4] Roll bundle to `hlc-401`: `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`. Verify MOTD/PS1/toolbox behavior on Pi 4.

### Silicon Wiring + Close Workarounds

- [ ] T079 [US4] Apply home-manager changes to `silicon`: `make silicon-switch`. Verify: toolbox commands available as `eaglerock@silicon`, no HLC MOTD in local terminal, workstation modules (i3, polybar) still functional.
- [ ] T080 [US4] Close W-001 in `WORKAROUNDS.md`: fill `Resolved: 2026-<date>`. All six US4 modules reintroduced with canary + smoke-test gates per exit condition.
- [ ] T081 [US4] Close W-003 in `WORKAROUNDS.md`: fill `Resolved: 2026-<date>`. `PasswordAuthentication = false` applied in T057, validated in T070.
- [ ] T082 [US4] Commit. Tag `phase5-operator-ux`.

**Checkpoint**: US4 complete. SC-006 verified. W-001 and W-003 closed.

---

## Phase 7: User Story 5 — k3s Prerequisites (Priority: P5)

**Goal**: Every in-scope node has k3s, k9s, container runtime, kernel/sysctl prereqs installed. k3s service enabled but stopped; no cluster state on disk.

**Independent Test**: On any provisioned node: `k3s --version`, `k9s --version`, `k version --client` succeed. `systemctl is-enabled k3s` → `enabled`. `systemctl is-active k3s` → `inactive`. `/var/lib/rancher/k3s/` absent or empty.

- [ ] T083 [US5] Create `modules/k8s/prereqs.nix`:
  - `services.k3s.enable = true` (installs binary + systemd unit)
  - `systemd.services.k3s.wantedBy = lib.mkForce [ ]` with comment: `# Enabled-but-stopped: follow-on cluster-bootstrap spec drops config and flips wantedBy back to [ "multi-user.target" ]`
  - `boot.kernelModules = [ "br_netfilter" "overlay" "ip_tables" ]`
  - `boot.kernel.sysctl = { "net.ipv4.ip_forward" = 1; "net.bridge.bridge-nf-call-iptables" = 1; "net.bridge.bridge-nf-call-ip6tables" = 1; }`
  - `systemd.enableCgroupAccounting = true` (cgroups v2)
  - `environment.systemPackages = with pkgs; [ k9s kubectl ]`
- [ ] T084 [US5] Update `modules/cluster/common.nix`: replace the `# TODO Phase 7: import ../k8s/prereqs.nix` stub with a real `import ../k8s/prereqs.nix`. Run `make dry-run HOST=hlc-501` — must succeed.
- [ ] T085 [US5] Run `make build HOST=hlc-501` — full build must succeed after T083–T084.
- [ ] T086 [US5] Apply k3s prereqs to `hlc-501`: `make update-node HOST=hlc-501` → `make smoke-test HOST=hlc-501` — green.
- [ ] T087 [US5] Verify k3s prereqs on `hlc-501`:
  - `ssh bob@hlc-501 "k3s --version"` — prints version (non-zero = fail)
  - `ssh bob@hlc-501 "k9s --version"` — prints version
  - `ssh bob@hlc-501 "k version --client"` — alias resolves to `kubectl version --client`
  - `ssh bob@hlc-501 "systemctl is-enabled k3s"` → `enabled`
  - `ssh bob@hlc-501 "systemctl is-active k3s"` → `inactive`
  - `ssh bob@hlc-501 "sudo test ! -d /var/lib/rancher/k3s || echo EMPTY"` → no cluster state
- [ ] T088 [US5] Verify kernel/sysctl prereqs on `hlc-501`:
  - `ssh bob@hlc-501 "lsmod | grep -E 'br_netfilter|overlay'"` — both loaded
  - `ssh bob@hlc-501 "sysctl net.ipv4.ip_forward"` → `1`
  - `ssh bob@hlc-501 "sysctl net.bridge.bridge-nf-call-iptables"` → `1`
  - `ssh bob@hlc-501 "cat /sys/fs/cgroup/cgroup.controllers"` — contains `memory cpu io` (cgroups v2 active)
- [ ] T089 [US5] Roll k3s prereqs to `hlc-502..508` serially: for each, `make update-node HOST=<host>` + `make smoke-test HOST=<host>`. Spot-check T087/T088 verifications on `hlc-504` (midpoint).
- [ ] T090 [US5] Roll k3s prereqs to `hlc-401` (Pi 4): `make update-node HOST=hlc-401` + `make smoke-test HOST=hlc-401`. Verify same T087/T088 checks pass on Pi 4.
- [ ] T091 [US5] Commit. Tag `phase6-k3s-prereqs`.

**Checkpoint**: US5 complete. SC-007 verified on all 9 work-set nodes.

---

## Phase 8: Polish & Cross-Cutting Validation

**Purpose**: Final acceptance criteria validation, documentation cleanup, spec close-out.

- [ ] T092 [P] Validate SC-001: time the workflow `make build-image HOST=hlc-501` → `make flash-image HOST=hlc-501 DEV=/dev/sdX` → power-on → `make smoke-test HOST=hlc-501` on a cold node (re-flashed to SD-only baseline). Operator wall-clock time excluding raw `dd` flash time MUST be ≤ 30 minutes.
- [ ] T093 [P] Validate SC-002: from a clean checkout (`git clone` or `git clean -fdx`), run `make dry-run HOST=<host>` for all 12 hosts. All MUST succeed with no manual edits.
- [ ] T094 [P] Validate SC-004: confirm `hlc-401` (Pi 4) and `hlc-501` (Pi 5) both boot, provision, and operate using the same `make` targets. No Pi-family-specific tooling required.
- [ ] T095 Validate SC-007 completeness: run T087/T088 checks on `hlc-401`, `hlc-501`, and two random Pi 5 nodes. All MUST pass.
- [ ] T096 Review `WORKAROUNDS.md`: W-001 Resolved ✅, W-003 Resolved ✅, W-002 Open (secrets management → feature 002). Confirm no untracked workarounds were introduced during implementation.
- [ ] T097 Update `quickstart.md` with any runtime-discovered deviations (e.g. if an EEPROM option name differed from the research, or a device path convention was different). Mark any such deviations in the relevant `research.md` open follow-ups as resolved.
- [ ] T098 Update `research.md` open follow-ups: mark as resolved — R-001 ✅ (nvmd confirmed working), R-004 (NVMe device path confirmed), R-005 (BOOT_ORDER value verified), R-011 (config.txt option path confirmed), R-013 (EEPROM service mechanism confirmed). Add any new findings discovered during implementation.
- [ ] T099 Final commit: `git commit -m "Phase 8: spec close-out — all acceptance criteria validated"`. Push branch and open PR for review.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup (T001–T008)**: ✅ Complete. No dependencies.
- **Phase 2 Foundational**: ✅ Complete (subsumed by Phase 1).
- **Phase 3 US1 (T009–T016)**: Depends on Phase 1. Independent of other user stories.
- **Phase 4 US2 (T017–T027)**: Depends on Phase 1. Independent of US1 (structural only; no physical hardware required).
- **Phase 5 US3 (T028–T050)**: Depends on US1 (working SD baseline for nixos-anywhere) AND US2 (per-host configs must exist).
- **Phase 6 US4 (T051–T082)**: Depends on US3 (nodes provisioned to accept `update-node`).
- **Phase 7 US5 (T083–T091)**: Depends on US3 (provisioned) AND US4 (`cluster/common.nix` wired; stub import already placed in T063).
- **Phase 8 Polish (T092–T099)**: Depends on all user stories complete.

### Dependency Graph

```text
US1 (T009-T016) ──────────────────────────────────► US3 (T028-T050)
US2 (T017-T027) ──────────────────────────────────►     └──► US4 (T051-T082)
                                                               └──► US5 (T083-T091)
                                                                     └──► Polish (T092-T099)
```

### Per-Phase Canary Cadence

| Phase | Canary | Fleet After |
| ----- | ------ | ----------- |
| US1 | hlc-501 (SD flash + smoke-test) | None (single-host) |
| US2 | All 12 via dry-run only | N/A (no live nodes) |
| US3 | hlc-501 (provision + recovery test) | hlc-502..508 then hlc-401 |
| US4 | hlc-501 (bundle update-node + smoke-test) | hlc-502..508 then hlc-401 + silicon |
| US5 | hlc-501 (update-node + k3s checks) | hlc-502..508 then hlc-401 |

### Parallel Opportunities Within Phases

- **US2 (Phase 4)**: T019+T020 (hardware stubs), T021+T022+T023 (host files) — all parallel.
- **US3 (Phase 5)**: T028+T029 (disko schemas), T030+T031 (hardware expansion), T040 (Pi 5 device IDs) — parallel.
- **US4 (Phase 6)**: T053 through T061 (module creation) — all parallel before T062 wiring.
- **Phase 8**: T092, T093, T094 — parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 3 US1 (T009–T016)
2. **STOP and VALIDATE**: SD baseline boots, cache invariant confirmed, smoke-test green
3. Proceed to US2+US3 only after US1 gate passes

### Incremental Delivery

1. US1 → SD baseline validated
2. US2 → All 12 host configs evaluate
3. US3 → All 9 nodes provisioned (cluster has durable storage)
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
