# Tasks: NixOS RPi Cluster Foundation — RESET (2026-04-26)

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Prerequisites**: plan.md (reset 2026-04-26), spec.md, research.md, data-model.md, quickstart.md

> **This file replaces the previous tasks.md wholesale.** The previous tasks
> targeted the failed Phase A (shared modules + 12 hosts in one push). This
> file targets the reset plan: triage, minimal-baseline, canary-driven
> remote update validation, then incremental module reintroduction.
>
> Tests are NOT explicitly requested. The functional equivalent here is
> `nix build` + `make smoke-test` + canary deploy + auto-rollback. Each
> task that adds runtime behavior includes a validation step.

**Organization**: Tasks grouped by Phase from plan.md. User-story labels:
- `[US1]` Nodes Online (P1, MVP) — Phase A0 → A1 → A2 → B
- `[US3]` Add New Hosts Without Rework — Phase C extensibility validation
- `[US4]` Consistent Shell Environment — Phase C reintroduction
- US2 (GitOps) and US5 (Day-2 maintenance) deferred to later /speckit-plan cycles after Phase C exits green; not in this tasks file.

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]** = parallelizable (different files, no incomplete deps)
- All paths absolute or repo-root-relative
- File paths are explicit per task

---

## Phase 1: Setup (Repository hygiene & tooling skeleton)

**Purpose**: Get the working tree to a known-good starting point before any rebuild work.

- [ ] T001 Stash or revert all uncommitted changes on `001-nixos-rpi-cluster` branch (`flake.nix`, `hosts/hlc-501/configuration.nix`, `hosts/hlc-502/configuration.nix`, `hosts/hlc-508/configuration.nix`, `modules/users/operator.nix`); commit revert as `chore(cluster): reset Phase A WIP for plan reset` so the branch starts the reset from a clean state matching commit `b432870`
- [ ] T002 [P] Create `scripts/` directory at repo root for shell helpers introduced by the reset plan
- [ ] T003 [P] Add `.gitignore` entry for `result*` symlinks if not already covered, so `nix build` outputs do not pollute the tree

**Checkpoint**: `git status` clean. `nix flake check` (or `make dry-run-all`) still passes against current modules. No new feature work yet.

---

## Phase 2: Foundational (Build/deploy/smoke-test tooling)

**Purpose**: Tooling that every subsequent phase depends on. Blocks all of Phase 3+.

**⚠️ CRITICAL**: No host-config work proceeds until smoke-test + canary tooling is in place. Without auto-rollback, the next bricked node is a physical-recovery event.

- [ ] T004 Create `scripts/smoke-test.sh` — POSIX shell. Args: `<host> <ip>`. Steps: (1) `ping -c1 -W2 $ip`; (2) `ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new bob@$ip true`; (3) `timeout 10 ssh -tt -o BatchMode=yes bob@$ip 'echo HELLO_$HOSTNAME && exit'` to verify a PTY session reaches a usable shell. Exit non-zero with descriptive error on any step failure. `chmod +x`.
- [ ] T005 Add `make smoke-test` target to `Makefile` invoking `scripts/smoke-test.sh $(HOST) $(IP)`; `HOST` and `IP` required
- [ ] T006 Add `make build HOST=hlc-NNN` target to `Makefile` running `nix build .#nixosConfigurations.$(HOST).config.system.build.toplevel -L --no-link`; this catches errors `dry-run` misses (full build closure)
- [ ] T007 Add `make canary HOST=hlc-NNN IP=<ip>` target to `Makefile` that: (1) runs `make build HOST=$(HOST)`; (2) runs `nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo`; (3) runs `make smoke-test HOST=$(HOST) IP=$(IP)`; (4) on smoke-test failure, runs `nixos-rebuild switch --rollback --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo` and exits non-zero. On success exits 0.
- [ ] T008 Add `make rollback HOST=hlc-NNN IP=<ip>` target to `Makefile` that runs `nixos-rebuild switch --rollback --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo` then `make smoke-test`; for manual recovery without invoking a forward switch first
- [ ] T009 Update `make help` block in `Makefile` to document the new targets (`build`, `smoke-test`, `canary`, `rollback`) under a clear "Phase A safety" heading

**Checkpoint**: `make help` shows new targets. `make build HOST=hlc-501` and `make smoke-test` invoke without syntax errors (smoke-test will fail until a node is online — that is fine; the script must exit non-zero cleanly).

---

## Phase 3: User Story 1 — Triage (Phase A0): recover bricked nodes 🎯 MVP-prereq

**Goal**: Reproduce the ssh-hang in a VM, identify the offending module/line, and reflash hlc-508 (currently off the network) with a known-good main-branch minimal config.

**Independent Test**: `make smoke-test HOST=hlc-508 IP=10.23.50.58` exits 0 (ping + non-PTY ssh + PTY ssh-to-prompt all pass). Same for hlc-501.

- [ ] T010 [US1] Reproduce ssh-hang locally: `nixos-rebuild build-vm --flake .#hlc-501` from current branch HEAD post-T001 revert; boot the VM; attempt `ssh bob@<vm-ip>`; record exact failure mode (timing, last visible log line, whether PTY ever allocates) in scratch notes
- [ ] T011 [US1] Bisect ssh-hang: `git diff main..HEAD -- hosts/hlc-501/configuration.nix modules/users/operator.nix modules/shell/ modules/motd/ modules/cluster/`; check out individual modules' import lines one at a time in a throwaway VM config; identify the first import that introduces the hang
- [ ] T012 [US1] Document root cause in `specs/001-nixos-rpi-cluster/research.md` § R-011 (placeholder already present): replace the "TODO" body with the bisect finding — exact module/file/line, reproduction steps, and the regression check that Phase C must run before reintroducing the offending module
- [ ] T013 [US1] Reflash hlc-508: pull SD physically; on gibson, build SD image from a hlc-508 host config that matches main-branch hlc-501 shape (board=bcm2712, hostname=hlc-508, useDHCP=true, openssh, bob user with key, stateVersion=25.11) — use a temporary patch on top of T001 revert; run `make build-image HOST=hlc-508` then `make flash-image HOST=hlc-508 DEV=/dev/sdX`; rerack; power on; confirm DHCP lease in Unifi
- [ ] T014 [US1] Smoke-test hlc-508: `make smoke-test HOST=hlc-508 IP=<dhcp-assigned-ip>`; must exit 0
- [ ] T015 [US1] If hlc-501 is unreachable (interactive ssh hang prevents `nixos-rebuild switch`), reflash it the same way as hlc-508 in T013–T014; otherwise leave hlc-501 in place pending Phase A1 rollout
- [ ] T016 [US1] Confirm any other physically-racked node responds to `ping` and basic ssh; record current reachability status in a comment on `specs/001-nixos-rpi-cluster/data-model.md` (do not yet edit the canonical IP/MAC tables)

**Checkpoint**: hlc-508 (and hlc-501 if needed) reachable via ssh. Root cause documented. Branch still on the T001 revert state — no host-config refactor yet.

---

## Phase 4: User Story 1 — Baseline (Phase A1): all 12 hosts on minimal config 🎯 MVP

**Goal**: All 12 HLC nodes running a ~12-line minimal config, reachable via ping + non-PTY ssh + PTY ssh, with `nixos-rebuild switch --target-host` validated working on at least one canary.

**Independent Test**: `for h in hlc-40{1..4} hlc-50{1..8}; do make smoke-test HOST=$h IP=$(grep $h docs/cluster-ips.txt | cut -f2); done` — all 12 exit 0. (Or equivalent loop reading IPs from `data-model.md`.)

### 4a: Refactor host configs to minimal shape (parallelizable per host)

Each task replaces the host's `configuration.nix` with the ~12-line shape from plan.md § Phase A1. **No imports.** No shared modules. No SSH hardening. No prompt. No MOTD. DHCP only. The pubkey string is hard-coded for now (parameterization returns in Phase 6).

- [ ] T017 [P] [US1] Rewrite `hosts/hlc-401/configuration.nix` to minimal Phase A1 shape with `raspberry-pi-nix.board = "bcm2711"`, `networking.hostName = "hlc-401"`, `networking.useDHCP = true`, `services.openssh.enable = true`, `users.users.bob = { isNormalUser = true; extraGroups = [ "wheel" ]; openssh.authorizedKeys.keys = [ "<gibson pubkey>" ]; }`, `security.sudo.wheelNeedsPassword = true` (passwordless wheel returns later), `system.stateVersion = "25.11"`; remove all module imports
- [ ] T018 [P] [US1] Rewrite `hosts/hlc-402/configuration.nix` — identical to T017 with hostname `hlc-402`, board `bcm2711`
- [ ] T019 [P] [US1] Rewrite `hosts/hlc-403/configuration.nix` — hostname `hlc-403`, board `bcm2711`
- [ ] T020 [P] [US1] Rewrite `hosts/hlc-404/configuration.nix` — hostname `hlc-404`, board `bcm2711`
- [ ] T021 [P] [US1] Rewrite `hosts/hlc-501/configuration.nix` — hostname `hlc-501`, board `bcm2712`
- [ ] T022 [P] [US1] Rewrite `hosts/hlc-502/configuration.nix` — hostname `hlc-502`, board `bcm2712`
- [ ] T023 [P] [US1] Rewrite `hosts/hlc-503/configuration.nix` — hostname `hlc-503`, board `bcm2712`
- [ ] T024 [P] [US1] Rewrite `hosts/hlc-504/configuration.nix` — hostname `hlc-504`, board `bcm2712`
- [ ] T025 [P] [US1] Rewrite `hosts/hlc-505/configuration.nix` — hostname `hlc-505`, board `bcm2712`
- [ ] T026 [P] [US1] Rewrite `hosts/hlc-506/configuration.nix` — hostname `hlc-506`, board `bcm2712`
- [ ] T027 [P] [US1] Rewrite `hosts/hlc-507/configuration.nix` — hostname `hlc-507`, board `bcm2712`
- [ ] T028 [P] [US1] Rewrite `hosts/hlc-508/configuration.nix` — hostname `hlc-508`, board `bcm2712` (matches the in-the-rack image from T013, just pulled into the flake/git source of truth)

### 4b: Simplify flake.nix wiring

- [ ] T029 [US1] Refactor `flake.nix` `nixosConfigurations` block: remove all `extraModules = []` debug entries and any `# DEBUG:` comments; ensure `mkHlcNode` (or equivalent helper) wires identical modules for all 12 hosts: `raspberry-pi-nix.nixosModules.raspberry-pi`, `raspberry-pi-nix.nixosModules.sd-image`, the per-board `nixos-hardware` module (`raspberry-pi-4` for hlc-40x, `raspberry-pi-5` for hlc-50x), and the host's own `configuration.nix`. No per-host module list divergence.
- [ ] T030 [US1] Run `make dry-run-all`; must exit 0 across all 12 hosts. If any host fails, fix in place before proceeding.

### 4c: Canary build + flash + boot — one Pi4 + one Pi5

- [ ] T031 [US1] `make build HOST=hlc-401` — full toplevel build must succeed (gates flashing)
- [ ] T032 [US1] `make build HOST=hlc-501` — full toplevel build must succeed
- [ ] T033 [US1] `make build-image HOST=hlc-401`; `make flash-image HOST=hlc-401 DEV=<sd>`; rack the SD; power on; wait for DHCP lease
- [ ] T034 [US1] `make smoke-test HOST=hlc-401 IP=<dhcp-ip>` — must exit 0; if it hangs or fails, **STOP**, return to Phase 3 triage
- [ ] T035 [US1] Same flow for hlc-501: `make build-image`, `make flash-image`, rack, power, `make smoke-test`
- [ ] T036 [US1] Record DHCP-assigned IPs for hlc-401 and hlc-501 in a new file `docs/cluster-ips.txt` (tab-separated `<hostname>\t<ip>\t<mac>`); this is the operational source of truth until Phase 5 introduces static IPs

### 4d: Roll to remaining 10 nodes (paired Pi4/Pi5, smoke-test after each)

- [ ] T037 [US1] hlc-402: `make build HOST=hlc-402`; flash; boot; `make smoke-test`; append IP to `docs/cluster-ips.txt`
- [ ] T038 [US1] hlc-502: same flow; append IP
- [ ] T039 [US1] hlc-403: same flow; append IP
- [ ] T040 [US1] hlc-503: same flow; append IP
- [ ] T041 [US1] hlc-404: same flow; append IP
- [ ] T042 [US1] hlc-504: same flow; append IP
- [ ] T043 [US1] hlc-505: same flow; append IP
- [ ] T044 [US1] hlc-506: same flow; append IP
- [ ] T045 [US1] hlc-507: same flow; append IP
- [ ] T046 [US1] hlc-508: re-flash with the now-flake-tracked `hosts/hlc-508/configuration.nix` (T028) so the in-rack image matches git; smoke-test; append IP

### 4e: Phase A1 exit gate

- [ ] T047 [US1] Run smoke-test loop across all 12 hosts (`for h in $HLC_HOSTS; do make smoke-test HOST=$h IP=$(grep -w $h docs/cluster-ips.txt | cut -f2); done`); all 12 exit 0
- [ ] T048 [US1] Commit: `feat(cluster): Phase A1 baseline — 12 minimal host configs, smoke-test tooling`; tag the commit `phase-a1-baseline` for easy rollback if Phase B regresses anything

**Checkpoint**: All 12 nodes reachable. No shared modules. Branch on a clean, green, taggable state. **MVP achieved**: User Story 1 acceptance scenarios 1–3 pass at minimal-config level.

---

## Phase 5: User Story 1 — Remote-update validation (Phase A2)

**Goal**: Prove `make canary` (build → switch → smoke-test → auto-rollback) actually works on real hardware for both Pi4 and Pi5. Without this, every Phase 6 module reintroduction risks bricking a node.

**Independent Test**: One Pi4 and one Pi5 each complete a forward + rollback cycle; both remain reachable.

- [ ] T049 [US1] Pick canary Pi4 hlc-404 (lowest blast radius — last server node). Edit `hosts/hlc-404/configuration.nix` to add a trivial change: `environment.systemPackages = [ pkgs.htop ];` (and the `pkgs` arg if not already in scope). Save.
- [ ] T050 [US1] `make canary HOST=hlc-404 IP=<ip>` — must exit 0 (build passes, switch succeeds, smoke-test green, no rollback triggered)
- [ ] T051 [US1] Verify behavior change: `ssh bob@<hlc-404-ip> 'which htop && htop --version'` returns a path and version
- [ ] T052 [US1] Trigger an explicit rollback: `make rollback HOST=hlc-404 IP=<ip>` — must exit 0; subsequent `ssh bob@<ip> 'which htop'` returns empty (htop gone)
- [ ] T053 [US1] Repeat T049–T052 on a Pi5 canary: hlc-508 (last worker — also lowest blast radius). Add `pkgs.htop`, canary, verify, rollback.
- [ ] T054 [US1] Test the negative path: deliberately introduce a broken change on hlc-508 (e.g., a typo'd module path or unknown option). Run `make canary` — expect non-zero exit. Confirm node is still reachable via `make smoke-test HOST=hlc-508 IP=<ip>` (auto-rollback fired). Revert the broken change. (Document this exercise in a comment in `quickstart.md` under Phase A2 — it's the single most important behavior to validate.)
- [ ] T055 [US1] Update `quickstart.md` Phase A2 section if T049–T054 surfaced any wrinkles in the canary flow (e.g., `--use-remote-sudo` requires NOPASSWD on `bob`; SSH known_hosts handling on first contact; rollback latency)
- [ ] T056 [US1] Commit: `feat(cluster): Phase A2 — canary deploy + auto-rollback validated on Pi4 and Pi5`; tag `phase-a2-validated`

**Checkpoint**: Remote-update path is provably safe. Phase 6 module reintroduction can begin.

---

## Phase 6: User Story 1 + 3 — Static IPs and host-key inventory (Phase B)

**Goal**: Move from DHCP-reservation addressing to declared static IPs in nix; capture each node's `ssh_host_ed25519_key.pub` for later sops-nix age use. Still no shared modules.

**Independent Test**: Each node reachable on its planned static IP per `data-model.md`; `docs/host-keys.txt` populated for all 12.

- [ ] T057 [US1] Update `data-model.md` IP/MAC table: ensure each of hlc-401–404 (`10.23.50.41–44`) and hlc-501–508 (`10.23.50.51–58`) is documented with planned static IP + recorded MAC from Unifi DHCP leases
- [ ] T058 [US1] Edit `hosts/hlc-404/configuration.nix` (canary) to replace `networking.useDHCP = true;` with `networking.useDHCP = false;` plus `networking.interfaces.eth0.ipv4.addresses = [{ address = "10.23.50.44"; prefixLength = 24; }];`, `networking.defaultGateway = "10.23.50.1";`, `networking.nameservers = [ "10.23.50.1" ];`
- [ ] T059 [US1] `make canary HOST=hlc-404 IP=10.23.50.44` — note: target IP changes from DHCP-leased to planned static. SSH the canary explicitly via `bob@10.23.50.44` after the switch to confirm reachability on the new address.
- [ ] T060 [P] [US1] Apply same edit to `hosts/hlc-401/configuration.nix` (IP `10.23.50.41`); `make canary HOST=hlc-401 IP=10.23.50.41`
- [ ] T061 [P] [US1] Apply to `hosts/hlc-402/configuration.nix` (IP `10.23.50.42`); canary
- [ ] T062 [P] [US1] Apply to `hosts/hlc-403/configuration.nix` (IP `10.23.50.43`); canary
- [ ] T063 [P] [US1] Apply to `hosts/hlc-501/configuration.nix` (IP `10.23.50.51`); canary
- [ ] T064 [P] [US1] Apply to `hosts/hlc-502/configuration.nix` (IP `10.23.50.52`); canary
- [ ] T065 [P] [US1] Apply to `hosts/hlc-503/configuration.nix` (IP `10.23.50.53`); canary
- [ ] T066 [P] [US1] Apply to `hosts/hlc-504/configuration.nix` (IP `10.23.50.54`); canary
- [ ] T067 [P] [US1] Apply to `hosts/hlc-505/configuration.nix` (IP `10.23.50.55`); canary
- [ ] T068 [P] [US1] Apply to `hosts/hlc-506/configuration.nix` (IP `10.23.50.56`); canary
- [ ] T069 [P] [US1] Apply to `hosts/hlc-507/configuration.nix` (IP `10.23.50.57`); canary
- [ ] T070 [P] [US1] Apply to `hosts/hlc-508/configuration.nix` (IP `10.23.50.58`); canary
- [ ] T071 [US1] Collect SSH host pubkeys: `for ip in 10.23.50.{41..44} 10.23.50.{51..58}; do ssh-keyscan -t ed25519 $ip; done > docs/host-keys.txt`; commit alongside `data-model.md` table update
- [ ] T072 [US1] Update `data-model.md` to include the recorded `ssh_host_ed25519_key.pub` for each node (column added to the existing IP/MAC table)
- [ ] T073 [US1] Commit: `feat(cluster): Phase B — static IPs + host-key inventory`; tag `phase-b-static-ips`

**Checkpoint**: All 12 nodes on declared static IPs; host pubkeys captured for sops-nix Phase D.

---

## Phase 7: User Story 4 — Layered module reintroduction (Phase C)

**Goal**: Reintroduce the previously-failed Phase A modules **one at a time, canary first**, with smoke-test gates and per-module commits. This phase resolves spec User Story 4 (consistent shell environment) and validates User Story 3 (modular extensibility) on real hardware.

**Independent Test per module**: After rollout, all 12 nodes pass `make smoke-test`, AND interactive `ssh bob@<host>` reaches a usable prompt within 5 seconds (manual check on at least 2 nodes per module — one Pi4, one Pi5).

**Process for every module below**:
1. Add/edit the module file under `modules/`.
2. Import it in **canary host hlc-404 only**.
3. `make build HOST=hlc-404` — full closure build must pass.
4. `make canary HOST=hlc-404 IP=10.23.50.44` — auto-rollback on smoke-test fail.
5. Manual interactive ssh test on hlc-404 (must reach prompt fast).
6. If green, import the module in remaining 11 hosts; canary each in turn.
7. Final loop: smoke-test all 12; tag commit.

### 7a: Module 1 — operator (parameterized bob user)

- [ ] T074 [US4] Edit `modules/users/operator.nix` to expose options (`users.operator.username`, `users.operator.sshKeys`, `users.operator.extraGroups`) and set `users.users.${cfg.username}` accordingly; **do NOT include the previously removed `services.openssh.settings` (ClientAlive/MaxStartups/PasswordAuthentication) block** — SSH hardening is module 6 below, kept separate; do set `security.sudo.wheelNeedsPassword = false` (or wire a separate option for it)
- [ ] T075 [US4] Edit `hosts/hlc-404/configuration.nix` to replace inline `users.users.bob` block with `imports = [ ../../modules/users/operator.nix ];` plus `users.operator.username = "bob"; users.operator.sshKeys = [ "<gibson pubkey>" ];`
- [ ] T076 [US4] `make build HOST=hlc-404`; `make canary HOST=hlc-404 IP=10.23.50.44`; manual `ssh bob@10.23.50.44` to verify prompt arrives normally
- [ ] T077 [P] [US4] Apply same import + option set to all remaining 11 hosts (`hlc-401, hlc-402, hlc-403, hlc-501, hlc-502, hlc-503, hlc-504, hlc-505, hlc-506, hlc-507, hlc-508`); canary each
- [ ] T078 [US4] Smoke-test loop all 12; commit `feat(cluster): Phase C.1 — operator module reintroduced`

### 7b: Module 2 — shell/common (bash defaults, no PROMPT_COMMAND)

- [ ] T079 [US4] Edit `modules/shell/common.nix` to set `programs.bash.enable = true;` plus history settings and aliases via `programs.bash.interactiveShellInit` only (not `shellInit`); no `promptInit`; no `PROMPT_COMMAND`
- [ ] T080 [US4] Import in hlc-404; `make build`; `make canary`; manual interactive ssh; if green, roll out
- [ ] T081 [P] [US4] Import `modules/shell/common.nix` in remaining 11 hosts; canary each
- [ ] T082 [US4] Smoke-test loop; commit `feat(cluster): Phase C.2 — shell/common module reintroduced`

### 7c: Module 3 — shell/prompt (HIGHEST RISK — suspected ssh-hang origin)

- [ ] T083 [US4] **Pre-canary regression check**: review the R-011 root cause documented in T012; if the cause was located in `modules/shell/prompt.nix`, fix the specific line/pattern (e.g., ensure `__git_ps1` source path resolves at activation time; ensure `PROMPT_COMMAND` is set exactly once; ensure the prompt block does not block on subshell expansion at login)
- [ ] T084 [US4] Edit `modules/shell/prompt.nix` to define the `shell.prompt.hostColor` option and a single-assignment `programs.bash.promptInit` that sets PS1 with optional git branch
- [ ] T085 [US4] Import in hlc-404 with `shell.prompt.hostColor = "\\[\\033[32m\\]";`; `make build`; `make canary`; **explicit interactive PTY ssh test** (NOT just `make smoke-test` — manually open `ssh bob@10.23.50.44`, confirm prompt within 5s, run a command, exit cleanly). This is the gate for whether the original ssh-hang regression is actually fixed.
- [ ] T086 [P] [US4] Import in remaining 11 hosts with appropriate per-host `shell.prompt.hostColor` (green for hlc-401–404 servers, cyan for hlc-501–508 workers); canary each with manual interactive ssh follow-up
- [ ] T087 [US4] Smoke-test loop + manual interactive PTY check on at least one Pi4 and one Pi5; commit `feat(cluster): Phase C.3 — shell/prompt reintroduced; ssh-hang regression closed`

### 7d: Module 4 — shell/utilities (sysadmin packages + syshelp)

- [ ] T088 [US4] Edit `modules/shell/utilities.nix` to add the alphabetically-sorted package list and the `pkgs.writeShellScriptBin "syshelp"` definition
- [ ] T089 [US4] Import in hlc-404; `make build`; `make canary`; verify `ssh bob@10.23.50.44 syshelp` prints categorized output and exits 0
- [ ] T090 [P] [US4] Import in remaining 11 hosts; canary each
- [ ] T091 [US4] Smoke-test loop; commit `feat(cluster): Phase C.4 — shell/utilities + syshelp reintroduced`
- [ ] T092 [P] [US4] Verify `docs/syshelp-reference.md` mirrors the categories/descriptions in `modules/shell/utilities.nix`; update if drifted

### 7e: Module 5 — motd (HLC ASCII banner + Bob Ross quote)

- [ ] T093 [US4] Edit `modules/motd/default.nix` to define the parameterized MOTD module (cluster name, ASCII art, tagline, attribution); writes to `environment.etc."motd".text`
- [ ] T094 [US4] Edit `modules/cluster/hlc/motd.nix` to set the HLC-specific values (banner, "We don't make mistakes, just happy little accidents.", "~ Bob Ross")
- [ ] T095 [US4] Import both in hlc-404; `make build`; `make canary`; verify MOTD displays on `ssh bob@10.23.50.44`
- [ ] T096 [P] [US4] Import in remaining 11 hosts; canary each
- [ ] T097 [US4] Smoke-test loop; commit `feat(cluster): Phase C.5 — MOTD reintroduced`

### 7f: Module 6 — SSH hardening (separate, last)

- [ ] T098 [US4] Add an opt-in `services.openssh.settings` block (`ClientAliveInterval = 30`, `ClientAliveCountMax = 3`, `LoginGraceTime = 20`, `MaxSessions = 20`, `MaxStartups = "30:30:60"`, `PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`, `UseDns = false`) — either as a new `modules/ssh/hardening.nix` or as an option flag on `modules/users/operator.nix`. Decide based on what tested cleanest in T010–T012 triage.
- [ ] T099 [US4] Import in hlc-404; `make build`; `make canary`; **explicit interactive ssh test** plus a forced-stale-session test: open two ssh sessions, `kill -STOP` one bash, wait 90s, confirm `MaxStartups` slot recovers and a third session can connect
- [ ] T100 [P] [US4] Import in remaining 11 hosts; canary each
- [ ] T101 [US4] Smoke-test loop; commit `feat(cluster): Phase C.6 — SSH hardening`; tag `phase-c-complete`

**Checkpoint**: All Phase A modules from the previous (failed) approach are reintroduced, validated incrementally, and any regression is traceable to its single-module commit. User Story 3 (extensibility) and User Story 4 (shell environment) acceptance criteria pass.

---

## Phase 8: Polish & Cross-Cutting

**Purpose**: Documentation refresh and surface-area cleanup before planning Phase D (disko/sops/k3s).

- [ ] T102 [P] Update `quickstart.md` end-to-end against current state of repo and tooling — remove any leftover references to features not yet implemented (k3s, ArgoCD, disko, sops); confirm Make targets listed match Makefile
- [ ] T103 [P] Update `README.md` if it references the old failed Phase A flow
- [ ] T104 [P] Add `.specify/feature.json` `phase` field bump or equivalent metadata to indicate Phase A→C complete; out-of-scope items D/E remain marked as deferred
- [ ] T105 Update `CLAUDE.md` agent context to point at `specs/001-nixos-rpi-cluster/plan.md` (already correct — confirm)
- [ ] T106 Run `make dry-run-all` one final time on the green Phase C state; confirm clean exit; this is the artifact to base the Phase D `/speckit-plan` cycle on

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No deps. Start immediately.
- **Phase 2 (Foundational tooling)**: Depends on Phase 1. **BLOCKS all of Phase 3+** — without canary + smoke-test + auto-rollback, no host change is safely deployable.
- **Phase 3 (A0 Triage)**: Depends on Phase 2. Recovers bricked nodes before Phase 4 mass rollout.
- **Phase 4 (A1 Baseline)**: Depends on Phase 3. Per-host config tasks (T017–T028) are parallelizable; flake wiring (T029) depends on those; build/flash/smoke-test (T031–T046) depend on T029–T030.
- **Phase 5 (A2 Validation)**: Depends on Phase 4 exit gate (T047).
- **Phase 6 (B Static IPs)**: Depends on Phase 5. Canary edit (T058–T059) before parallel rollout (T060–T070).
- **Phase 7 (C Modules)**: Depends on Phase 6. Each sub-phase 7a–7f is sequential — never bundle two modules in one canary.
- **Phase 8 (Polish)**: Depends on Phase 7.

### User Story Dependencies

- **US1 (Nodes Online, P1)**: Phases 3 → 4 → 5 → 6. **MVP at end of Phase 4 (T048)** — that's the smallest deliverable that fulfills US1's "all 12 nodes Ready" acceptance scenarios for the non-k3s portion.
- **US3 (Add New Hosts)**: implicitly validated throughout Phase 7 — every successful module reintroduction across 12 host configs is the test.
- **US4 (Shell Environment)**: Phase 7 in entirety.
- **US2 (GitOps), US5 (Day-2 Maintenance)**: deferred — re-plan after Phase 8.

### Within Each Phase

- Phase 4 host rewrites (T017–T028) parallelizable across hosts but T029 must follow.
- Phase 6 canary (T058–T059) must precede the parallel rollout (T060–T070).
- Phase 7 sub-phases (7a–7f) run sequentially. Within each sub-phase, the canary host edit/build/canary precedes the `[P]` parallel rollout to remaining 11.

### Parallel Opportunities

- Phase 4 host config rewrites: T017–T028 (12 tasks) — different files, no cross-deps
- Phase 6 static-IP edits: T060–T070 — but each host's `make canary` must run sequentially (one operator), so the parallelism is in the edit, not the deploy
- Phase 7 module rollouts to non-canary hosts (T077, T081, T086, T090, T096, T100) — same caveat: edits parallel, canaries serial
- Phase 8 doc updates: T102–T104

---

## Parallel Example: Phase 4 host rewrites

```bash
# Edits in parallel (different files):
Task: "Rewrite hosts/hlc-401/configuration.nix to minimal Phase A1 shape"
Task: "Rewrite hosts/hlc-402/configuration.nix"
Task: "Rewrite hosts/hlc-403/configuration.nix"
# ... through hlc-508

# Then sequentially:
make dry-run-all    # T030 — must pass before any flash
make build HOST=hlc-401 && make build HOST=hlc-501    # T031, T032
# Flash, boot, smoke-test (T033–T036) — physical steps, serial
```

---

## Implementation Strategy

### MVP First — User Story 1 to end of Phase 4

1. Phase 1: Setup (T001–T003)
2. Phase 2: Foundational tooling (T004–T009) — **without this, do not proceed**
3. Phase 3: A0 Triage (T010–T016) — recover hlc-508
4. Phase 4: A1 Baseline (T017–T048) — all 12 minimal-config nodes online
5. **STOP and VALIDATE**: smoke-test loop green, tag `phase-a1-baseline`
6. This is the MVP. The feature spec's User Story 1 acceptance scenarios 1–3 pass at this point (modulo k3s, which is a separate spec phase).

### Incremental delivery after MVP

1. Phase 5: prove canary + auto-rollback (T049–T056) → tag `phase-a2-validated`
2. Phase 6: static IPs + host keys (T057–T073) → tag `phase-b-static-ips`
3. Phase 7: one module at a time (T074–T101) → tag `phase-c-complete`
4. Phase 8: polish (T102–T106)

Each tag is a known-good rollback point. If a module reintroduction in Phase 7 surfaces a regression, `git checkout phase-c-N` and `make canary` per host returns the cluster to the previous-module known-good state — incremental detection of which exact module broke things, which is the user's stated requirement.

### Single-operator strategy

This work is done by one operator (no parallel humans). Parallelism here means file edits — never simultaneous deploys to multiple hosts. Always one canary, then serial rollout, smoke-test in between.

---

## Notes

- `[P]` tasks = different files, safe to edit concurrently. Deploys themselves are always serial.
- `[Story]` label maps task to the spec user story it serves. US2 and US5 deliberately absent from this file.
- Every host-touching task has an implicit pre-flight `make build` and post-flight `make smoke-test` — codified in `make canary`. Use plain `make update-node` only when the same change has already been canary-validated on another node.
- Commit cadence: one commit per sub-phase exit gate (T030, T048, T056, T073, T078, T082, T087, T091, T097, T101). Tag at major phase boundaries. This gives a clean bisect target for any regression.
- If Phase 3 triage cannot reproduce the ssh-hang in a VM, do **not** skip the documentation step (T012). Note the inability to reproduce in research.md § R-011 with as much detail as available — Phase 7c (shell/prompt) is the next-most-likely place the hang re-emerges, and an undocumented original failure mode makes that diagnosis harder.
