# Tasks: NixOS RPi Cluster Foundation

**Feature**: `001-nixos-rpi-cluster` | **Regenerated**: 2026-04-26
**Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)
**Scope**: Phases A0 → C (foundation through module reintroduction). Phases D/E deferred.

> **Plan reset 2026-04-26 (round 4)**: Shell modules stripped from host configs.
> Phase A0 = verify minimal baseline + boot canaries.
> Phase A1 = inline tool packages only, default bash prompt.
> Phase C = module reintroduction one-at-a-time.
> PS1 fix (prompt.nix \033→\e) deferred to Phase C step 4 (research.md R-011).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Parallel-safe (different files, no deps on incomplete tasks)
- **[Story]**: User story label — [US1]–[US5] match spec.md priorities

---

## Phase 1: Setup (Baseline Verification)

**Purpose**: Confirm repo state correct before hardware work.

> All 12 host configs already at minimal baseline (no shell/prompt/motd imports).
> Verify before touch hardware.

- [X] T001 Verify all 12 `hosts/hlc-NNN/configuration.nix` have no shell/prompt/motd module imports; run `make dry-run-all` — must exit 0
- [ ] T002 [P] Capture silicon's PS1 via `ssh silicon 'echo "$PS1"'`; add as `R-012` in `specs/001-nixos-rpi-cluster/research.md` (needed before Phase C prompt.nix fix)
- [X] T003 [P] Verify `WORKAROUNDS.md` entries W-001 (Principle III deferral), W-002 (passwordless wheel), W-003 (PasswordAuthentication default) present with correct exit conditions

---

## Phase 2: Foundational — Phase A0 (Canary boot verification)

**Purpose**: Prove Pi4 + Pi5 minimal configs boot + accept SSH.

**⚠️ CRITICAL**: Both canaries must pass smoke-test before Phase 3.

- [ ] T004 Build Pi4 canary toplevel: `make build HOST=hlc-401` — must succeed
- [ ] T005 [P] Build Pi5 canary toplevel: `make build HOST=hlc-501` — must succeed
- [ ] T006 Flash hlc-401 SD: `make flash-image HOST=hlc-401 DEV=<dev>`; insert SD, power on, wait DHCP
- [ ] T007 [P] Flash hlc-501 SD: `make flash-image HOST=hlc-501 DEV=<dev>`; insert SD, power on, wait DHCP
- [ ] T008 Smoke-test Pi4 canary: `make smoke-test HOST=hlc-401 IP=10.23.50.41`; verify default bash prompt on interactive SSH (kitty: `TERM=xterm-256color ssh bob@10.23.50.41`)
- [ ] T009 Smoke-test Pi5 canary: `make smoke-test HOST=hlc-501 IP=10.23.50.51`; verify default bash prompt

**Checkpoint — A0 exit gate**: Both canaries green. If hlc-401 unreachable: check DHCP MAC reservation in Unifi, confirm bcm2711 board (not bcm2712), try different SD.

---

## Phase 3: US1 — Provision Cluster Nodes (P1) 🎯 MVP

**Goal**: All 9 work-set nodes booted, SSH reachable, standard tools installed, both update paths validated.

**Independent Test**: `make smoke-test` passes for all 9 work-set nodes; `git --version`, `htop`, `jq`, `ripgrep`, `tmux` available on each.

### A1 — Standard tool packages

- [X] T010 [P] [US1] Add `environment.systemPackages = with pkgs; [ git htop jq ripgrep tmux ];` (alphabetic) inline to `hosts/hlc-401/configuration.nix`
- [X] T011 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-501/configuration.nix`
- [X] T012 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-502/configuration.nix`
- [X] T013 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-503/configuration.nix`
- [X] T014 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-504/configuration.nix`
- [X] T015 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-505/configuration.nix`
- [X] T016 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-506/configuration.nix`
- [X] T017 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-507/configuration.nix`
- [X] T018 [P] [US1] Add `environment.systemPackages` inline to `hosts/hlc-508/configuration.nix`
- [X] T019 [US1] Run `make dry-run-all` after T010–T018 done — must exit 0
- [ ] T020 [US1] Canary deploy Pi5 first: `make canary HOST=hlc-501 IP=10.23.50.51`; SSH in, verify `git --version`, `htop`, `jq`, `ripgrep`, `tmux` present; default bash prompt intact
- [ ] T021 [US1] Canary deploy Pi4: `make canary HOST=hlc-401 IP=10.23.50.41`; same tool check
- [ ] T022 [US1] Roll to hlc-502: `make canary HOST=hlc-502 IP=10.23.50.52`; `make smoke-test` must pass
- [ ] T023 [US1] Roll to hlc-503: `make canary HOST=hlc-503 IP=10.23.50.53`; `make smoke-test` must pass
- [ ] T024 [US1] Roll to hlc-504: `make canary HOST=hlc-504 IP=10.23.50.54`; `make smoke-test` must pass
- [ ] T025 [US1] Roll to hlc-505: `make canary HOST=hlc-505 IP=10.23.50.55`; `make smoke-test` must pass
- [ ] T026 [US1] Roll to hlc-506: `make canary HOST=hlc-506 IP=10.23.50.56`; `make smoke-test` must pass
- [ ] T027 [US1] Roll to hlc-507: `make canary HOST=hlc-507 IP=10.23.50.57`; `make smoke-test` must pass
- [ ] T028 [US1] Roll to hlc-508: `make canary HOST=hlc-508 IP=10.23.50.58`; `make smoke-test` must pass

**Checkpoint — A1 exit gate**: All 9 work-set nodes pass smoke-test; tools available; default bash prompt on interactive SSH.

### A2 — Update path validation

- [ ] T029 [US1] Validate workstation-push forward+rollback on hlc-501: trivial change → `make canary HOST=hlc-501 IP=10.23.50.51` → `nixos-rebuild switch --rollback --target-host bob@10.23.50.51` → `make smoke-test HOST=hlc-501 IP=10.23.50.51` → re-deploy to restore
- [ ] T030 [US1] Repeat forward+rollback on hlc-401 (Pi4)
- [ ] T031 [US1] Test on-device git fallback on hlc-501: `ssh bob@10.23.50.51`, `git clone <repo-url> /tmp/nix-config`, `cd /tmp/nix-config && sudo nixos-rebuild switch --flake .#hlc-501`; document result (success / OOM / speed) as `R-013` in `specs/001-nixos-rpi-cluster/research.md`
- [ ] T032 [US1] Rewrite `specs/001-nixos-rpi-cluster/quickstart.md`: SD flash → boot → smoke → canary → roll; workstation push primary; on-device fallback w/ caveats (Pi4 may OOM); kitty TERM workaround; direct SSH instructions

**Checkpoint — A2 exit gate**: ≥1 Pi4 + 1 Pi5 complete forward+rollback cycle; on-device attempt documented.

### B — Static IPs + SSH host key inventory

- [ ] T033 [US1] Add static IP config inline to `hosts/hlc-501/configuration.nix` (`networking.interfaces.eth0.ipv4.addresses`, `networking.defaultGateway`, `networking.nameservers`); `make canary HOST=hlc-501 IP=10.23.50.51`; smoke-test
- [ ] T034 [US1] Roll static IP to `hosts/hlc-401/configuration.nix`; `make canary HOST=hlc-401 IP=10.23.50.41`; smoke-test
- [ ] T035 [US1] Roll static IP to `hosts/hlc-502` thru `hosts/hlc-508` one at time: `make canary HOST=hlc-50X IP=10.23.50.5X`; `make smoke-test` after each
- [ ] T036 [US1] Collect `ssh_host_ed25519_key.pub` from all 9 nodes (`ssh bob@<ip> 'cat /etc/ssh/ssh_host_ed25519_key.pub'`); convert each to age pubkey via `ssh-to-age`; record all 9 age pubkeys in `specs/001-nixos-rpi-cluster/data-model.md`

**Checkpoint — B exit gate**: All 9 nodes reachable on static IPs; `data-model.md` has age pubkeys for all 9.

---

## Phase 4: US4 — Consistent Shell Environment (P3)

**Goal**: All 9 work-set nodes have parameterized user module, syshelp, styled PS1, MOTD via shared modules. Principle III deferral (W-001) retired.

**Independent Test**: SSH any HLC node as `bob`; MOTD shows HLC ASCII art + hostname + Bob Ross quote; `syshelp` lists utilities; PS1 renders without escape artifacts.

**Prerequisites**: B exit gate passes.

> One canary cycle per module. hlc-501 always canary. Never bundle modules.

- [ ] T037 [US4] Verify/create `modules/users/operator.nix` parameterized user module (username option, wheel group, openssh.authorizedKeys from option); import in `hosts/hlc-501/configuration.nix`; `make build HOST=hlc-501` → `make canary HOST=hlc-501 IP=10.23.50.51` → SSH verify; roll to remaining 8 nodes
- [ ] T038 [US4] Verify/create `modules/shell/utilities.nix` w/ alphabetic packages (git, htop, jq, ripgrep, tmux) + `pkgs.writeShellScriptBin "syshelp"` script; remove inline `environment.systemPackages` from each host config; canary hlc-501; roll to all 9
- [ ] T039 [US4] Verify/create `modules/shell/common.nix` (bash history settings, aliases); canary hlc-501; roll to all 9
- [ ] T040 [US4] Fix `modules/shell/prompt.nix`: replace all `\033[` with `\e[` in color var defs; remove wrapping double-quotes from color var values (see research.md R-011); attempt `nixos-rebuild build-vm` if aarch64 VM feasible; `make build HOST=hlc-501` → `make canary HOST=hlc-501 IP=10.23.50.51` → explicit interactive PTY SSH to verify no escape artifacts → roll to all 9
- [ ] T041 [US4] Verify/create `modules/motd/default.nix` (parameterized w/ `environment.etc."motd".text`); verify/create `modules/cluster/hlc/motd.nix` (HLC ASCII art + hostname + Bob Ross quote replicating Debian MOTD); canary hlc-501; roll to all 9; verify MOTD on login
- [ ] T042 [US4] SSH hardening canary: disable PasswordAuthentication in openssh settings (separate module or in operator.nix); canary hlc-501; verify SSH still works; roll to all 9; mark W-003 resolved in `WORKAROUNDS.md`
- [ ] T043 [US4] Mark W-001 (Principle III deferral) resolved in `WORKAROUNDS.md`; run `make dry-run-all` to confirm all 12 hosts evaluate clean

**Checkpoint — C exit gate per module**: all 9 work-set nodes pass smoke-test after each module rollout; interactive PTY SSH explicitly tested for T040 (prompt.nix).
**Checkpoint — C exit gate**: All modules deployed; `nixos-rebuild dry-run` (via `make dry-run`) passes for hlc-402/403/404.

---

## Phase 5: US3 — Add New Hosts Without Structural Rework (P3)

**Goal**: ecto-1 stub validates extensible module structure; no existing files modified.

**Independent Test**: `make dry-run HOST=ecto1-001` succeeds without touching any existing host config or module file.

**Prerequisites**: Phase C complete (modules exist to import).

- [ ] T044 [P] [US3] Create `modules/cluster/ecto1/` stub w/ `default.nix` placeholder; parameterize `slimer` user; generic hostname-only MOTD banner
- [ ] T045 [US3] Create `hosts/ecto1-001/configuration.nix` importing shared modules (users/operator.nix w/ username=slimer, ecto1 MOTD stub); add to `flake.nix` nixosConfigurations; `make dry-run HOST=ecto1-001` must pass with no changes to existing files

**Checkpoint**: Stub evaluates clean; SC-004 satisfied.

---

## Phase 6: US5 — Maintain Cluster Configuration Over Time (P5)

**Goal**: Rolling update procedure documented, `update-cluster` target verified.

**Independent Test**: `nix flake update` → `make dry-run-all` passes → roll one Pi4 + one Pi5 via `make update-node`; cluster quorum maintained.

**Prerequisites**: Phase C complete.

- [ ] T046 [US5] Verify `update-cluster` Makefile target uses correct serial roll order (Pi4 servers: hlc-402 → hlc-403 → hlc-404 → hlc-401 last for quorum stability; Pi5 workers: any order); `make smoke-test` gate after each node; add target if missing
- [ ] T047 [US5] Add rolling update runbook section to `specs/001-nixos-rpi-cluster/quickstart.md`: `nix flake update` → `make dry-run-all` → roll control nodes (quorum invariant: never fewer than 2 healthy server nodes during update) → roll workers → verify `kubectl get nodes` all Ready

---

## Phase 7 (Deferred): Phases D/E — Storage + GitOps

> Plan at next `/speckit-plan` invocation after Phase C exits green.
> No task IDs assigned yet.

**Phase D** (US1 storage layer — FR-003, FR-004, FR-005):
- disko config: SD boot + 2× USB mdadm RAID1 root (`by-id` device paths); `boot.initrd.mdadmConf`
- sops-nix: admin age key on gibson; `.sops.yaml` w/ all 12 recipients; `secrets/hlc.yaml` k3s token
- nixos-anywhere: kexec aarch64 image; provision hlc-401 first (`clusterInit = true`)
- Pi5 NVMe: one partition reserved for Longhorn; not used as root
- RAID1 redundancy verification before production workloads

**Phase E** (US2 GitOps — FR-006, FR-007, FR-012):
- k3s: server config (hlc-401 clusterInit; hlc-402–404 join via serverAddr); agent config (hlc-501–508)
- Cgroup kernel params in `modules/hardware/rpi4.nix` + `modules/hardware/rpi5.nix`
- Firewall ports: TCP 6443/2379-2380/10250; UDP 8472/51820
- ArgoCD bootstrap (`kubectl apply` — one-time manual)
- Longhorn w/ NixOS-compatible images (research.md R-006)
- cert-manager + ingress for marks.dev hostnames
- DNS/DHCP/Unifi cutover runbook from Debian cluster

---

## Dependencies & Execution Order

```
Phase 1 (Setup)
  └── Phase 2 (A0: boot canaries)
        └── Phase 3 (US1: A1 tool packages → A2 update validation → B static IPs)
              └── Phase 4 (US4: module reintroduction, C exit gate)
                    ├── Phase 5 (US3: ecto-1 stub)
                    └── Phase 6 (US5: rolling update runbook)
```

### Within Phase 3 (US1)

- T010–T018: All parallel (separate files)
- T019: Depends on T010–T018
- T020: Depends on T019
- T021: Depends on T020 (Pi5 canary must pass first)
- T022–T028: Depend on T021
- T029–T032 (A2): Depend on T022–T028
- T033–T036 (B): Depend on T032

### Within Phase 4 (US4)

T037 → T038 → T039 → T040 → T041 → T042 → T043 — strict sequential, one module per canary cycle.

### Parallel Opportunities

- T004/T005: Pi4 + Pi5 builds simultaneously
- T006/T007: SD flashing on separate hardware
- T010–T018: All 9 systemPackages edits simultaneously

---

## Parallel Example: Phase A1 systemPackages

```bash
# All 9 host config edits simultaneously (T010–T018):
Edit hosts/hlc-401/configuration.nix
Edit hosts/hlc-501/configuration.nix
...
Edit hosts/hlc-508/configuration.nix

# Then single gate (T019):
make dry-run-all

# Then sequential canary deploys (T020 → T021 → T022…):
make canary HOST=hlc-501 IP=10.23.50.51   # Pi5 canary first
make canary HOST=hlc-401 IP=10.23.50.41   # then Pi4
# then hlc-502 through hlc-508 one at a time
```

---

## Implementation Strategy

### Immediate MVP (Phases 1–3, US1 only)

1. T001–T003: Verify baseline
2. T004–T009: A0 — boot canaries (A0 exit gate)
3. T010–T028: A1 — tool packages, canary, roll (A1 exit gate)
4. T029–T032: A2 — update path validation
5. T033–T036: B — static IPs + host keys (B exit gate)
6. **Stop**: Cluster baseline established. Phases D/E begin after planning.

### Shell Environment (Phase 4, US4)

After B exit gate:
7. T037–T043: Phase C — one module per canary cycle (C exit gate)

### Notes

- T002 (silicon PS1 capture for R-012) must happen before T040 (prompt.nix fix)
- `make canary` = build + `nixos-rebuild switch --target-host` + smoke-test + auto-rollback on failure
- Decommissioned-set hlc-402/403/404: dry-run only; NEVER flash or `nixos-rebuild switch`
- kitty users: `TERM=xterm-256color ssh bob@<host>` or use alacritty (known limitation — research.md R-011)