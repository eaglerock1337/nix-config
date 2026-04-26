# Tasks: NixOS RPi Cluster Foundation — RESET v2 (constitution v1.1.0)

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Prerequisites**: plan.md (reset 2026-04-26), spec.md, constitution v1.1.0, research.md, data-model.md, quickstart.md

> **Replaces previous tasks.md.** Adjusted to constitution v1.1.0:
> - **Work-set** (active rollout): `hlc-401` + `hlc-501`–`hlc-508` = 9 nodes.
> - **Decommissioned-set** (Debian, untouchable until parity cutover):
>   `hlc-402`, `hlc-403`, `hlc-404`. Host configs may exist in flake for
>   dry-run, but **no SD flash, no `nixos-rebuild switch`** invoked
>   against them in this cycle.
> - Workarounds tracked in `WORKAROUNDS.md` per Principle V. Ledger file
>   created at first workaround entry; not blocking other work.
> - Password auth remains enabled as short-term fallback until nodes are
>   stable (W-003); SSH hardening (T091) closes that workaround.
> - Critical fixes from `/speckit-analyze` baked in: `wheelNeedsPassword
>   = false` in baseline (avoids canary breakage), smoke-test purges
>   stale host keys before probe, T013/T028 sequencing corrected, sub-
>   phase tags added for finer `git bisect` granularity.

**Organization**: Tasks grouped by Phase from plan.md.
- `[US1]` Nodes Online (P1, MVP) — Phases A1 → A2 → B (Phase A0 is optional fallback)
- `[US3]` Add New Hosts Without Rework — Phase C extensibility
- `[US4]` Consistent Shell Environment — Phase C reintroduction
- US2 (GitOps) and US5 (Day-2 maintenance) deferred to later /speckit-plan cycles.

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]** = parallelizable (different files, no incomplete deps)
- All paths absolute or repo-root-relative
- Work-set tasks act on 9 nodes: `hlc-401, hlc-501..508`
- Decommissioned-set tasks (hlc-402–404) limited to flake config + dry-run

## Canonical minimal host-config shape (Phase 4 baseline)

Used by every host-config task in Phase 4 (T015 hlc-508 if recovery needed,
T023–T031 work-set, T032–T034 decommissioned-set). ~13 lines per host. No
imports. No shared modules. No SSH hardening. No prompt. No MOTD. DHCP only.

```nix
{ ... }: let
  # Operator pubkey is hoisted to flake.nix as a let-binding (T036a) and
  # passed in via specialArgs as `operatorPubkey`. Until that hoist lands,
  # the literal RSA key from main:hosts/hlc-501/configuration.nix
  # ("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3...eaglerock@gibson")
  # is inlined here.
in {
  raspberry-pi-nix.board = "bcm2711";   # bcm2712 for Pi5
  networking.hostName = "hlc-NNN";
  networking.useDHCP = true;
  services.openssh.enable = true;
  # NOTE: PasswordAuthentication left at NixOS default (true) per
  # WORKAROUNDS W-003 — short-term fallback so a misconfigured authorized_keys
  # cannot brick a headless node. Closes at T104 (Phase 7f SSH hardening).
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ <operator pubkey> ];
  };
  security.sudo.wheelNeedsPassword = false;   # WORKAROUNDS W-002
  system.stateVersion = "25.11";
}
```

Decommissioned-set hosts (hlc-402/403/404) use the same shape but add a
header comment forbidding flash/switch (per § Cluster Topology).

## Fastest-path note (operator's stated priority)

To **image and ssh-onto a single node ASAP** (your stated goal), the strict
critical path is: T001 → T015 (write canonical config for chosen first
node) → T035 (clean flake.nix wiring) → T037 (`make dry-run-all`) → existing
`make build-image` + `make flash-image` (already in main-branch Makefile) →
rack + power + manual `ssh bob@<dhcp-ip>`. Phase 2 tooling (T004–T011 — the
`smoke-test`, `canary`, `rollback`, `ip` Make targets) is required for
**Phase 5+** remote-update validation but is **not blocking** the first
imaging pass. Operator MAY run Phase 2 in parallel with first SD flashes.
The full Phase 2 + Phase 4 ordering below is the safe path; the fastest
path is a documented subset.

---

## Phase 1: Setup (Repository hygiene & tooling skeleton)

- [ ] T001 Stash or revert remaining uncommitted Phase-A WIP on the working tree (any leftover after the constitution commit). Check `git status`; if not clean, commit revert as `chore(cluster): clean working tree before tasks reset` so subsequent host-config rewrites diff cleanly.
- [ ] T002 [P] Create `scripts/` directory at repo root for shell helpers introduced by reset plan
- [ ] T003 [P] Verify `.gitignore` covers `result*` symlinks (Nix build outputs); append if missing

**Checkpoint**: `git status` clean. `make dry-run-all` still passes for current modules. No new feature work yet.

---

## Phase 2: Foundational (Build/deploy/smoke-test tooling)

**⚠️ BLOCKS Phase 4 *canary loop*** (T043+, Phase 5+, Phase 7+). Does NOT block the Phase 4 first-flash sequence — that uses existing main-branch `make build-image` + `make flash-image` + manual `ssh` (per Fastest-path note). Operator MAY run Phase 2 in parallel with the first SD flash.

- [ ] T004 Create `scripts/smoke-test.sh` — POSIX shell. Args: `<host> <ip>`. Steps: (1) `ssh-keygen -R "$ip" >/dev/null 2>&1` to purge stale host key (reflashed nodes generate new keys); (2) `ping -c1 -W2 "$ip"`; (3) `ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new bob@$ip true`; (4) `timeout 10 ssh -tt -o BatchMode=yes bob@$ip 'echo HELLO_$(hostname) && exit'` for PTY validation; (5) `ssh -o BatchMode=yes bob@$ip 'sudo -n true' 2>/dev/null` to confirm `--use-remote-sudo` will work (requires `wheelNeedsPassword = false` per W-002); stderr suppressed so a config-drift password prompt does not spam operator terminal. Exit non-zero with descriptive error on any step failure. `chmod +x`.
- [ ] T005 Add `make smoke-test HOST=hlc-NNN IP=<ip>` target to `Makefile` invoking `scripts/smoke-test.sh $(HOST) $(IP)`; both vars required
- [ ] T006 Add `make build HOST=hlc-NNN` target to `Makefile` running `nix build .#nixosConfigurations.$(HOST).config.system.build.toplevel -L --no-link`
- [ ] T007 Add `make canary HOST=hlc-NNN IP=<ip>` target: (1) `make build`; (2) `nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo`; (3) `make smoke-test`; (4) on smoke-test fail, run `nixos-rebuild switch --rollback --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo` then exit non-zero
- [ ] T008 Add `make rollback HOST=hlc-NNN IP=<ip>` target: `nixos-rebuild switch --rollback ...` then `make smoke-test`
- [ ] T009 Add `make ip HOST=hlc-NNN` helper target: `@grep -w '^$(HOST)' docs/cluster-ips.txt | cut -f2`. Used by smoke-test loops once `docs/cluster-ips.txt` is populated.
- [ ] T010 Add `make smoke-test-all` target looping over work-set hosts only (`hlc-401 hlc-501..508`), reading IPs from `docs/cluster-ips.txt`; do NOT include hlc-402/403/404 (decommissioned-set)
- [ ] T011 Update `make help` block in `Makefile` to document new targets under "Phase A safety" heading; also document the work-set vs decommissioned-set distinction in a comment near the `HLC_HOSTS` variable

**Checkpoint**: `make help` shows new targets. `make build HOST=hlc-501` and `make smoke-test` invoke without syntax errors.

---

## Phase 3: User Story 1 — Triage (A0) — OPTIONAL FALLBACK

**Status**: **Skip by default.** Invoked only if Phase 4 first-canary
(T041 hlc-401 or T042 hlc-501) fails to come up reachable on the clean
baseline. The clean baseline does NOT import any of the modules
suspected of causing the prior ssh-hang, so the bug is sidestepped if
the baseline boots successfully. Triage is needed only when the
baseline itself fails.

**Goal (if invoked)**: Reproduce the failure, identify the root cause
(could be hardware, raspberry-pi-nix pin, nixos-hardware option drift
on 25.11, or the original module bug surfacing at boot rather than
login), document for Phase 7 reintroduction.

**Independent Test**: `make smoke-test HOST=<failing-host> IP=<ip>` exits 0.

- [ ] T012 [US1] (optional) Reproduce failure locally: `nixos-rebuild build-vm --flake .#<failing-host>`; boot VM; attempt `ssh bob@<vm-ip>`; record exact failure mode (timing, last visible log line, whether PTY allocates, kernel panic, etc.) in scratch notes
- [ ] T013 [US1] (optional) If failure is shell/login-time (PTY hang) and the baseline imports no shell/MOTD modules, the suspect is *not* the prior-art bug — investigate kernel/hardware/raspberry-pi-nix pin. If the baseline somehow imports a regressed module, bisect: `git diff main..HEAD -- hosts/<host>/configuration.nix modules/users/operator.nix modules/shell/ modules/motd/ modules/cluster/`
- [ ] T014 [US1] (optional) Document root cause in `specs/001-nixos-rpi-cluster/research.md` § R-011: failing-host name, exact module/file/line if module-related, reproduction steps, regression check that Phase 7 must run before reintroducing the offending module. If failure cannot be reproduced in build-vm, record that explicitly with all available signal.

> Recovery flashing of an unreachable node (e.g., hlc-508 from prior reset
> attempt) is handled in Phase 4 alongside the first-image flow — not here.
> The baseline config produced in Phase 4 IS the recovery image.

---

## Phase 4: User Story 1 — Baseline (A1): work-set on minimal config 🎯 MVP

**Goal**: 9 work-set nodes (`hlc-401`, `hlc-501`–`hlc-508`) booted on minimal config, reachable via ping + non-PTY ssh + PTY ssh, validated by smoke-test.

**Independent Test**: `make smoke-test-all` exits 0 across 9 work-set hosts.

### 4a: Canonical minimal shape (workaround tracking)

- [ ] T020 [US1] Open `WORKAROUNDS.md` (create if absent) and add entry `W-001`: inline host configs duplicate ~12 lines across 9 work-set hosts (defers Principle III); exit condition = Phase 7 module reintroduction complete; target phase = current /speckit-plan cycle Phases 7a–7f
- [ ] T021 [US1] Add entry `W-002` to `WORKAROUNDS.md`: `security.sudo.wheelNeedsPassword = false` in baseline (defers eventual passwordless-via-key+sops state); exit condition = secrets management + sops-nix integration deployed; target phase = future feature spec for Phase D
- [ ] T022 [US1] Add entry `W-003` to `WORKAROUNDS.md`: `PasswordAuthentication = true` (NixOS 25.11 default; FR-011 violation window) — kept as short-term fallback per operator decision so a node that breaks `authorized_keys` is not bricked; exit condition = T091 SSH hardening rolled out across all work-set nodes; target phase = Phase 7f. Code comments in baseline host configs reference this entry.

### 4b: Rewrite work-set host configs to minimal shape (parallelizable)

Canonical minimal shape (per host, ~13 lines incl. workaround comment):

```nix
{ ... }: {
  raspberry-pi-nix.board = "bcm2711";   # bcm2712 for Pi5
  networking.hostName = "hlc-NNN";
  networking.useDHCP = true;
  services.openssh.enable = true;
  # NOTE: PasswordAuthentication left at default (true) per WORKAROUNDS W-003;
  # closes at Phase 7f T091.
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "<gibson-rsa-pubkey from main:hosts/hlc-501/configuration.nix>" ];
  };
  security.sudo.wheelNeedsPassword = false;   # WORKAROUNDS W-002
  system.stateVersion = "25.11";
}
```

The pubkey is the existing RSA key from `main` branch `hosts/hlc-501/configuration.nix` (the `eaglerock@gibson` key). Use the literal string for now; centralization deferred to Phase 7a (operator module).

- [ ] T023 [P] [US1] Rewrite `hosts/hlc-401/configuration.nix` to minimal shape with `board = "bcm2711"`, hostname `hlc-401`. Note: hlc-401 is the cluster bootstrap node (k3s `clusterInit = true`) but k3s configuration is deferred — Phase 4 minimal shape only.
- [ ] T024 [P] [US1] Rewrite `hosts/hlc-501/configuration.nix` to minimal shape, board `bcm2712`, hostname `hlc-501`
- [ ] T025 [P] [US1] Rewrite `hosts/hlc-502/configuration.nix` — hostname `hlc-502`, board `bcm2712`
- [ ] T026 [P] [US1] Rewrite `hosts/hlc-503/configuration.nix` — hostname `hlc-503`, board `bcm2712`
- [ ] T027 [P] [US1] Rewrite `hosts/hlc-504/configuration.nix` — hostname `hlc-504`, board `bcm2712`
- [ ] T028 [P] [US1] Rewrite `hosts/hlc-505/configuration.nix` — hostname `hlc-505`, board `bcm2712`
- [ ] T029 [P] [US1] Rewrite `hosts/hlc-506/configuration.nix` — hostname `hlc-506`, board `bcm2712`
- [ ] T030 [P] [US1] Rewrite `hosts/hlc-507/configuration.nix` — hostname `hlc-507`, board `bcm2712`
- [ ] T031 [US1] Verify `hosts/hlc-508/configuration.nix` matches the minimal shape (already written in T015 for triage flash); reconcile if drift

### 4c: Decommissioned-set host configs — minimal shape, dry-run only

Constitution v1.1.0 § Cluster Topology forbids flashing/switching these. Configs exist so flake evaluates and so future decommission day is one edit away.

- [ ] T032 [P] [US1] Rewrite `hosts/hlc-402/configuration.nix` to minimal shape, hostname `hlc-402`, board `bcm2711`. Add header comment: `# DECOMMISSIONED-SET — currently Debian. Do NOT flash or nixos-rebuild switch this host. See constitution v1.1.0 § Cluster Topology.`
- [ ] T033 [P] [US1] Rewrite `hosts/hlc-403/configuration.nix` similarly, hostname `hlc-403`
- [ ] T034 [P] [US1] Rewrite `hosts/hlc-404/configuration.nix` similarly, hostname `hlc-404`

### 4d: Flake wiring + dry-run gate

- [ ] T035 [US1] Refactor `flake.nix` `nixosConfigurations` block: remove all `extraModules = []` debug entries and `# DEBUG:` comments; ensure all 12 host nixosConfigurations use a uniform helper (e.g., `mkHlcNode`) wiring `raspberry-pi-nix.nixosModules.raspberry-pi`, `raspberry-pi-nix.nixosModules.sd-image`, the per-board `nixos-hardware` module, and the host's own `configuration.nix`. No per-host module-list divergence.
- [ ] T036 [US1] Add `WORK_SET = hlc-401 hlc-501 hlc-502 hlc-503 hlc-504 hlc-505 hlc-506 hlc-507 hlc-508` and `DECOM_SET = hlc-402 hlc-403 hlc-404` variables to `Makefile`; `HLC_HOSTS = $(WORK_SET) $(DECOM_SET)` for dry-run-all only
- [ ] T037 [US1] `make dry-run-all` — must exit 0 for all 12 hosts (work-set + decom-set). If any host fails, fix before proceeding.

### 4e: Canary build + flash + boot — one Pi4 + one Pi5

- [ ] T038 [US1] `make build HOST=hlc-401` — full toplevel build must succeed (gates flashing)
- [ ] T039 [US1] `make build HOST=hlc-501` — full toplevel build must succeed
- [ ] T040 [US1] `make build-image HOST=hlc-401`; `make flash-image HOST=hlc-401 DEV=<sd>`; rack the SD; power on; wait for DHCP lease
- [ ] T041 [US1] `make smoke-test HOST=hlc-401 IP=<dhcp-ip>` — must exit 0; append IP to `docs/cluster-ips.txt`. If hangs/fails, **STOP**, return to Phase 3.
- [ ] T042 [US1] Same flow for hlc-501: `make build-image`; `make flash-image`; rack; power; `make smoke-test`; append IP
- [ ] T043 [US1] **First canary remote-update test**: edit `hosts/hlc-501/configuration.nix` to add `environment.systemPackages = [ pkgs.htop ];` (and switch fn signature to `{ pkgs, ... }:`); run `make canary HOST=hlc-501 IP=<ip>`; must exit 0. This validates the canary loop on real hardware before mass rollout.
- [ ] T044 [US1] Roll back the htop test: `make rollback HOST=hlc-501 IP=<ip>`; remove `environment.systemPackages` from the file. Smoke-test still green.

### 4f: Roll to remaining 7 work-set Pi5 nodes

Pair Pi5 builds. Smoke-test after each. (hlc-508 already online from T017; reflash with the canonical config from T031 if needed.)

- [ ] T045 [US1] hlc-502: `make build`; flash; boot; smoke-test; append IP
- [ ] T046 [US1] hlc-503: same flow; append IP
- [ ] T047 [US1] hlc-504: same flow; append IP
- [ ] T048 [US1] hlc-505: same flow; append IP
- [ ] T049 [US1] hlc-506: same flow; append IP
- [ ] T050 [US1] hlc-507: same flow; append IP
- [ ] T051 [US1] hlc-508: re-flash with the now-flake-tracked `hosts/hlc-508/configuration.nix` (T031) so in-rack image matches git; smoke-test; confirm IP in docs/cluster-ips.txt
- [ ] T052 [US1] (Skipped — no further work-set Pi5 nodes; hlc-401 covered in T040–T041)

### 4g: Phase A1 exit gate

- [ ] T053 [US1] `make smoke-test-all` — all 9 work-set hosts exit 0
- [ ] T054 [US1] Commit `feat(cluster): Phase A1 baseline — 9 work-set host configs, smoke-test tooling`; tag commit `phase-a1-baseline`

**Checkpoint**: 9 work-set nodes reachable. Decommissioned-set configs in flake but not flashed. **MVP achieved**: spec US1 acceptance scenarios 1–3 pass at minimal-config level for the work-set.

---

## Phase 5: User Story 1 — Remote-update validation (A2)

**Goal**: Prove `make canary` (build → switch → smoke-test → auto-rollback) reliable for both Pi4 and Pi5.

**Independent Test**: One Pi4 (hlc-401) and one Pi5 (already done in T043 for hlc-501) each complete forward + rollback + deliberate-break-with-auto-rollback cycles.

- [ ] T055 [US1] hlc-401 forward canary: edit `hosts/hlc-401/configuration.nix` to add `environment.systemPackages = [ pkgs.htop ];` (and `{ pkgs, ... }:`); `make canary HOST=hlc-401 IP=<ip>`; must exit 0
- [ ] T056 [US1] Verify behavior change: `ssh bob@<hlc-401-ip> 'which htop && htop --version'`
- [ ] T057 [US1] Manual rollback: `make rollback HOST=hlc-401 IP=<ip>`; `ssh bob@<ip> 'which htop'` returns empty
- [ ] T058 [US1] **Negative path** — deliberate break: introduce a typo or unknown option in `hosts/hlc-401/configuration.nix` (e.g., `services.openssh.enabel = true;`); `make canary HOST=hlc-401 IP=<ip>` — expect non-zero exit either at `make build` (caught at build) or at `make smoke-test` (caught post-switch with auto-rollback). Confirm node reachable: `make smoke-test HOST=hlc-401 IP=<ip>`. Revert the broken change.
- [ ] T059 [US1] Same negative-path test on a Pi5 (hlc-505 recommended — last in worker order, lowest blast radius)
- [ ] T060 [US1] Update `quickstart.md` Phase A2 with any wrinkles surfaced (sudo NOPASSWD requirement, host-key handling, rollback latency)
- [ ] T061 [US1] Commit `feat(cluster): Phase A2 — canary deploy + auto-rollback validated on Pi4 and Pi5`; tag `phase-a2-validated`

**Checkpoint**: Remote-update path is provably safe. Phase 7 module reintroduction unlocked.

---

## Phase 6: User Story 1 — Static IPs + host-key inventory (B)

**Goal**: Replace DHCP-reservation addressing with declared static IPs in nix; capture each work-set node's `ssh_host_ed25519_key.pub` for later sops-nix age use. Decommissioned-set hosts (hlc-402–404) get static-IP entries in their flake configs **but no flash/switch** — config is for the future decommission day.

**Independent Test**: All 9 work-set nodes reachable on planned static IPs; `docs/host-keys.txt` populated for 9 nodes.

- [ ] T062 [US1] Update `data-model.md` IP/MAC table: confirm hlc-401→`10.23.50.41`, hlc-501–508→`10.23.50.51..58`, hlc-402–404→`10.23.50.42..44` (flake-only). Record actual MACs from Unifi DHCP leases.
- [ ] T063 [US1] Edit `hosts/hlc-401/configuration.nix` (canary): replace `useDHCP = true` with `useDHCP = false` plus `interfaces.eth0.ipv4.addresses = [{ address = "10.23.50.41"; prefixLength = 24; }];`, `defaultGateway = "10.23.50.1";`, `nameservers = [ "10.23.50.1" ];`
- [ ] T064 [US1] `make canary HOST=hlc-401 IP=10.23.50.41` — note target IP changes from DHCP-leased to planned static. `ssh bob@10.23.50.41` after to confirm reachability on new address.
- [ ] T065 [P] [US1] Apply same edit to `hosts/hlc-501/configuration.nix` (IP `10.23.50.51`); `make canary HOST=hlc-501 IP=10.23.50.51`
- [ ] T066 [P] [US1] hlc-502 → `10.23.50.52`; canary
- [ ] T067 [P] [US1] hlc-503 → `10.23.50.53`; canary
- [ ] T068 [P] [US1] hlc-504 → `10.23.50.54`; canary
- [ ] T069 [P] [US1] hlc-505 → `10.23.50.55`; canary
- [ ] T070 [P] [US1] hlc-506 → `10.23.50.56`; canary
- [ ] T071 [P] [US1] hlc-507 → `10.23.50.57`; canary
- [ ] T072 [P] [US1] hlc-508 → `10.23.50.58`; canary
- [ ] T073 [P] [US1] Add static-IP block to `hosts/hlc-402/configuration.nix` (`10.23.50.42`); **flake-only, no canary**. Comment: `# Decommissioned-set; flake-evaluating only. Do not switch.`
- [ ] T074 [P] [US1] Same for `hosts/hlc-403/configuration.nix` (`10.23.50.43`)
- [ ] T075 [P] [US1] Same for `hosts/hlc-404/configuration.nix` (`10.23.50.44`)
- [ ] T076 [US1] `make dry-run-all` — all 12 hosts pass eval
- [ ] T077 [US1] Collect SSH host pubkeys for work-set: `for ip in 10.23.50.41 10.23.50.{51..58}; do ssh-keyscan -t ed25519 $ip; done > docs/host-keys.txt`
- [ ] T078 [US1] Add SSH `ssh_host_ed25519_key.pub` column to `data-model.md` table for the 9 work-set nodes; decommissioned-set rows note "pending decommission"
- [ ] T079 [US1] Commit `feat(cluster): Phase B — static IPs + host-key inventory (work-set)`; tag `phase-b-static-ips`

**Checkpoint**: 9 work-set nodes on static IPs. Host pubkeys captured. Decommissioned-set host configs flake-evaluable for future cutover day.

---

## Phase 7: User Story 4 — Layered module reintroduction (C)

**Goal**: Reintroduce previously-failed Phase A modules **one at a time, canary first**, with smoke-test gates and per-module commits + tags. Resolves spec User Story 4 and validates User Story 3 on real hardware.

**Independent Test per module**: After rollout, all 9 work-set nodes pass `make smoke-test`, AND interactive `ssh bob@<host>` reaches a usable prompt within 5 seconds (manual on at least 1 Pi4 + 1 Pi5).

**Process for every module 7a–7f**:
1. Add/edit the module file under `modules/`.
2. Import in **canary host hlc-401 only** (Pi4 server canary; lowest blast radius for control-plane modules).
3. `make build HOST=hlc-401` — full closure must pass.
4. `make canary HOST=hlc-401 IP=10.23.50.41` — auto-rollback on smoke-test fail.
5. Manual interactive ssh on hlc-401 — prompt within 5s.
6. If green, import in remaining 8 work-set hosts; canary each in turn.
7. Smoke-test all 9; commit; **tag** `phase-c.N-<module>`.

> Decommissioned-set hosts (hlc-402–404) do not import these modules in this cycle — adding modules to those configs is a future cutover task.

### 7a: Module 1 — operator (parameterized bob user)

- [ ] T080 [US4] Edit `modules/users/operator.nix`: options `users.operator.username`, `users.operator.sshKeys`, `users.operator.extraGroups`; sets `users.users.${cfg.username}` accordingly. **Do NOT include the `services.openssh.settings` block** — SSH hardening is module 7f, kept separate. Set `security.sudo.wheelNeedsPassword = false` (W-002 still in force).
- [ ] T081 [US4] Edit `hosts/hlc-401/configuration.nix`: replace inline `users.users.bob` with `imports = [ ../../modules/users/operator.nix ];` plus `users.operator.username = "bob"; users.operator.sshKeys = [ "<gibson-rsa-pubkey>" ];`
- [ ] T082 [US4] `make build HOST=hlc-401`; `make canary HOST=hlc-401 IP=10.23.50.41`; manual `ssh bob@10.23.50.41` to verify prompt arrives normally
- [ ] T083 [P] [US4] Apply same import + option set to remaining 8 work-set hosts (hlc-501–508); canary each
- [ ] T084 [US4] `make smoke-test-all`; commit `feat(cluster): Phase C.1 — operator module`; tag `phase-c.1-operator`. Update `WORKAROUNDS.md` W-001 progress note.

### 7b: Module 2 — shell/common (bash defaults, no PROMPT_COMMAND)

- [ ] T085 [US4] Edit `modules/shell/common.nix`: `programs.bash.enable = true`; history settings + aliases via `programs.bash.interactiveShellInit` only (NOT `shellInit` — must not pollute non-interactive contexts); no `promptInit`; no `PROMPT_COMMAND`
- [ ] T086 [US4] Import in hlc-401; `make build`; `make canary`; manual interactive ssh; if green, roll out
- [ ] T087 [P] [US4] Import `modules/shell/common.nix` in remaining 8 work-set hosts; canary each
- [ ] T088 [US4] `make smoke-test-all`; commit `feat(cluster): Phase C.2 — shell/common module`; tag `phase-c.2-shell-common`

### 7c: Module 3 — shell/prompt (HIGHEST RISK — suspected ssh-hang origin)

- [ ] T089 [US4] **Pre-canary regression check**: review R-011 root cause from T014; if cause was in `modules/shell/prompt.nix`, fix the specific line/pattern (`__git_ps1` source path resolves at activation; `PROMPT_COMMAND` set exactly once; no blocking subshell expansion at login)
- [ ] T090 [US4] Edit `modules/shell/prompt.nix`: option `shell.prompt.hostColor` and a single-assignment `programs.bash.promptInit` that sets PS1 with optional git branch
- [ ] T091 [US4] Import in hlc-401 with `shell.prompt.hostColor = "\\[\\033[32m\\]";` (green = server); `make build`; `make canary`; **explicit interactive PTY ssh test** — manually `ssh bob@10.23.50.41`, prompt within 5s, run a command, exit cleanly. This is the gate for whether the original ssh-hang is closed.
- [ ] T092 [P] [US4] Import in remaining 8 work-set hosts with appropriate `shell.prompt.hostColor` (cyan `\\[\\033[36m\\]` for hlc-501–508 workers); canary each with manual interactive ssh follow-up
- [ ] T093 [US4] `make smoke-test-all` + manual interactive PTY check on hlc-401 + hlc-505; commit `feat(cluster): Phase C.3 — shell/prompt; ssh-hang regression closed`; tag `phase-c.3-shell-prompt`

### 7d: Module 4 — shell/utilities (sysadmin packages + syshelp)

- [ ] T094 [US4] Edit `modules/shell/utilities.nix`: alphabetically-sorted package list (`curl`, `dnsutils`, `ethtool`, `fd`, `file`, `git`, `htop`, `iotop`, `jq`, `lsof`, `mtr`, `ncdu`, `nmap`, `pciutils`, `ripgrep`, `tcpdump`, `tmux`, `tree`, `usbutils`, `wget`) + `pkgs.writeShellScriptBin "syshelp"` printing categorized colorized output (Network, Storage, Process, Search, Data, Dev)
- [ ] T095 [US4] Import in hlc-401; `make build`; `make canary`; verify `ssh bob@10.23.50.41 syshelp` prints categorized output and exits 0
- [ ] T096 [P] [US4] Import in remaining 8 work-set hosts; canary each
- [ ] T097 [US4] Verify/update `docs/syshelp-reference.md` mirrors categories + descriptions in `modules/shell/utilities.nix`
- [ ] T098 [US4] `make smoke-test-all`; commit `feat(cluster): Phase C.4 — shell/utilities + syshelp`; tag `phase-c.4-shell-utilities`

### 7e: Module 5 — motd (HLC ASCII banner + Bob Ross quote)

- [ ] T099 [US4] Edit `modules/motd/default.nix`: parameterized MOTD (`cluster.motd.enable`, `clusterName`, `asciiArt`, `tagline`, `attribution`); writes `environment.etc."motd".text`
- [ ] T100 [US4] Edit `modules/cluster/hlc/motd.nix`: HLC values (banner, "We don't make mistakes, just happy little accidents.", "~ Bob Ross")
- [ ] T101 [US4] Import both in hlc-401; `make build`; `make canary`; verify MOTD displays on `ssh bob@10.23.50.41`
- [ ] T102 [P] [US4] Import in remaining 8 work-set hosts; canary each
- [ ] T103 [US4] `make smoke-test-all`; commit `feat(cluster): Phase C.5 — MOTD`; tag `phase-c.5-motd`

### 7f: Module 6 — SSH hardening (closes W-003)

- [ ] T104 [US4] Add `services.openssh.settings` block (`ClientAliveInterval = 30`, `ClientAliveCountMax = 3`, `LoginGraceTime = 20`, `MaxSessions = 20`, `MaxStartups = "30:30:60"`, `PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`, `UseDns = false`) — either as new `modules/ssh/hardening.nix` or as an option on `modules/users/operator.nix`. Decision based on what tested cleanest in Phase 3 triage.
- [ ] T105 [US4] Import in hlc-401; `make build`; `make canary`; **explicit interactive ssh test** plus forced-stale-session test: open two ssh sessions, `kill -STOP` one bash, wait 90s, confirm `MaxStartups` slot recovers and a third session connects
- [ ] T106 [P] [US4] Import in remaining 8 work-set hosts; canary each
- [ ] T107 [US4] `make smoke-test-all` + retry the interactive PTY check on at least 2 hosts; commit `feat(cluster): Phase C.6 — SSH hardening`; tag `phase-c.6-ssh-hardening`
- [ ] T108 [US4] **Close workaround**: edit `WORKAROUNDS.md` W-003 entry → set `Resolved: <today>`. Reference the T107 commit/tag.

**Checkpoint**: All Phase A modules from previous attempt reintroduced incrementally. Per-module tags in place for `git bisect`-style regression isolation. Spec User Story 3 (extensibility) and User Story 4 (shell environment) acceptance criteria pass. W-001 also closes once T084 commit is verified — note that in `WORKAROUNDS.md` immediately after T084.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T109 [P] Update `quickstart.md` end-to-end against current state of repo and tooling — confirm Make targets listed match Makefile; add a "decommissioned-set rules" subsection mirroring constitution v1.1.0 § Cluster Topology
- [ ] T110 [P] Update `README.md` if it references the old failed Phase A flow
- [ ] T111 [P] Update `CLAUDE.md` plan reference confirmed pointing at `specs/001-nixos-rpi-cluster/plan.md` (no edit if already correct)
- [ ] T112 Final `make dry-run-all` on green Phase 7 state — clean exit. Artifact for the next /speckit-plan cycle (Phase D disko/sops, then Phase E k3s/ArgoCD).
- [ ] T113 `WORKAROUNDS.md` review: ensure W-001 and W-003 are marked resolved with commit references; W-002 remains open with target = "Phase D secrets/sops feature spec"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No deps.
- **Phase 2 (Foundational tooling)**: Depends on Phase 1. **BLOCKS all of Phase 3+.**
- **Phase 3 (A0 Triage)**: Depends on Phase 2. Must complete before any work-set node mass rollout.
- **Phase 4 (A1 Baseline)**: Depends on Phase 3. Per-host config tasks (T023–T034) parallelizable; flake wiring (T035) depends on those; build/flash/smoke-test (T038–T053) depend on T037.
- **Phase 5 (A2 Validation)**: Depends on Phase 4 exit gate (T054).
- **Phase 6 (B Static IPs)**: Depends on Phase 5. Canary edit (T063–T064) before parallel rollout (T065–T076).
- **Phase 7 (C Modules)**: Depends on Phase 6. Sub-phases 7a–7f sequential — never bundle two modules in one canary.
- **Phase 8 (Polish)**: Depends on Phase 7.

### Decommissioned-Set Constraint (constitution v1.1.0)

Tasks T032–T034 (host configs), T073–T075 (static IP entries) for `hlc-402/403/404` are **flake-only**. NO `make build-image`, NO `make flash-image`, NO `make canary`, NO `make update-node`, NO `nixos-rebuild switch --target-host` is permitted against these hosts in this entire tasks file. Their participation is limited to `make dry-run-all` evaluation. Decommission + reflash of 402–404 is a future feature spec, after work-set reaches feature parity with the old Debian cluster and DNS cutover completes.

### User Story Dependencies

- **US1 (Nodes Online, P1)**: Phases 3 → 4 → 5 → 6. **MVP at end of Phase 4 (T054)**.
- **US3 (Add New Hosts)**: implicitly validated throughout Phase 7 — every successful module rollout across 9 work-set hosts is the test.
- **US4 (Shell Environment)**: Phase 7 in entirety.
- **US2 (GitOps), US5 (Day-2 Maintenance)**: deferred — re-plan after Phase 8.

### Parallel Opportunities

- Phase 4 host config rewrites: T023–T030 (work-set Pi5s + hlc-401), T032–T034 (decom-set) — different files, no cross-deps
- Phase 6 static-IP edits: T065–T075 (edits parallel; canaries serial, one operator)
- Phase 7 module rollouts to non-canary hosts (T083, T087, T092, T096, T102, T106): edits parallel; canaries serial
- Phase 8 doc updates: T109–T111

---

## Parallel Example: Phase 4 host rewrites

```bash
# Edits in parallel:
Task: "Rewrite hosts/hlc-401/configuration.nix to minimal Phase A1 shape"
Task: "Rewrite hosts/hlc-501/configuration.nix to minimal Phase A1 shape"
# ... through hlc-508 (work-set)
Task: "Rewrite hosts/hlc-402/configuration.nix — decom-set, flake-only"
# ... through hlc-404 (decom-set)

# Then sequentially:
make dry-run-all     # T037 — must pass before any flash
make build HOST=hlc-401 && make build HOST=hlc-501    # T038, T039
# Flash, boot, smoke-test (T040–T044) — physical, serial
```

---

## Implementation Strategy

### MVP First — User Story 1 to end of Phase 4

1. Phase 1: Setup (T001–T003)
2. Phase 2: Foundational tooling (T004–T011) — without this, do not proceed
3. Phase 3: A0 Triage (T012–T019) — reflash hlc-508 (and any other unreachable work-set node)
4. Phase 4: A1 Baseline (T020–T054) — 9 work-set nodes online; decom-set configs in flake but unflashed
5. **STOP and VALIDATE**: smoke-test loop green; tag `phase-a1-baseline`

### Incremental delivery after MVP

1. Phase 5 → tag `phase-a2-validated`
2. Phase 6 → tag `phase-b-static-ips`
3. Phase 7 sub-phases 7a–7f → tags `phase-c.1-operator` through `phase-c.6-ssh-hardening`
4. Phase 8 → polish

Each tag is a known-good rollback point. `git bisect` against tags pins regressions to a single sub-phase / module.

### Single-operator strategy

Parallelism = file edits only. Deploys serial. One canary, then serial rollout, smoke-test in between.

---

## Notes

- `[P]` = different files, edit-time parallelism only. Deploys are always serial.
- `[Story]` maps task → spec user story for traceability. US2/US5 absent from this file.
- Every host-touching task has implicit pre-flight `make build` and post-flight `make smoke-test` — codified in `make canary`. Use plain `make update-node` only when a change has been canary-validated on another node first.
- Commit cadence: one commit per sub-phase exit gate (T037, T054, T061, T079, T084, T088, T093, T098, T103, T107). Tag at each major + sub-phase boundary. Clean bisect target for any regression.
- If Phase 3 cannot reproduce the ssh-hang in a VM, do NOT skip T014 — note inability to reproduce in research.md § R-011 with all available signal. Phase 7c (shell/prompt) is the next-most-likely re-emergence point.
- `WORKAROUNDS.md` is created by T020. Subsequent workaround entries get appended at the task that introduces them. Resolutions edit-in-place per constitution governance section.
- Decommissioned-set boundary: if you find yourself typing `hlc-402`, `hlc-403`, or `hlc-404` after a `make` target other than `dry-run-all` or `dry-run`, **stop**. That is a constitution v1.1.0 violation.
