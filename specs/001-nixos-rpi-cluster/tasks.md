# Tasks: NixOS RPi Cluster Foundation

**Input**: Design documents from `/specs/001-nixos-rpi-cluster/`
**Branch**: `001-nixos-rpi-cluster`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Exact file paths in descriptions

---

## Phase A0: Triage & PS1 Fix

**Goal**: Unblock remaining work — fix garbled PS1 on hlc-501, restore hlc-401 reachability.

- [ ] T001 Fix `\033` → `\e` and remove wrapping double-quotes in `modules/shell/prompt.nix`
- [ ] T002 Validate fix: `nixos-rebuild dry-run --flake .#hlc-501` then `nix build .#nixosConfigurations.hlc-501.config.system.build.toplevel`
- [ ] T003 Deploy fixed prompt to hlc-501: `make canary HOST=hlc-501 IP=10.23.50.51`; confirm PS1 correct via interactive SSH
- [ ] T004 Triage hlc-401 unreachability (DHCP/MAC, image mismatch, SD card, switch port); reflash Pi4 image if needed
- [ ] T005 Confirm A0 exit gate: `make smoke-test HOST=hlc-501` passes; hlc-401 reachable via ping and SSH

---

## Phase A1: Shell Baseline Across Work-Set [US4]

**Goal**: All 9 work-set nodes have `common.nix` + fixed `prompt.nix`; colored PS1 confirmed on each.

**Independent Test**: `make smoke-test` passes all 9 nodes; interactive SSH shows correct PS1.

- [ ] T006 [US4] Capture silicon PS1 format via SSH and add `R-012` entry to `specs/001-nixos-rpi-cluster/research.md`
- [ ] T007 [US4] Add `modules/shell/common.nix` + `modules/shell/prompt.nix` imports to `hosts/hlc-401/configuration.nix`; canary deploy + smoke-test + interactive SSH check
- [ ] T008 [P] [US4] Add shell module imports to `hosts/hlc-502/configuration.nix` and `hosts/hlc-503/configuration.nix`; canary deploy pair + smoke-test both
- [ ] T009 [P] [US4] Add shell module imports to `hosts/hlc-504/configuration.nix` and `hosts/hlc-505/configuration.nix`; canary deploy pair + smoke-test both
- [ ] T010 [P] [US4] Add shell module imports to `hosts/hlc-506/configuration.nix` and `hosts/hlc-507/configuration.nix`; canary deploy pair + smoke-test both
- [ ] T011 [US4] Add shell module imports to `hosts/hlc-508/configuration.nix`; canary deploy + smoke-test
- [ ] T012 [US4] Confirm A1 exit gate: all 9 nodes pass `make smoke-test`; interactive SSH shows correct PS1 on each

---

## Phase A2: Update Path Validation [US5]

**Goal**: Prove workstation-push and on-device-git paths both work before adding features.

**Independent Test**: hlc-401 and hlc-501 complete forward+rollback canary cycle; on-device result documented.

- [ ] T013 [US5] Validate workstation push on hlc-401: trivial change → `make canary` → smoke-test → rollback → re-deploy; confirm both directions work
- [ ] T014 [US5] Validate workstation push on hlc-501: same cycle as T013
- [ ] T015 [US5] Test on-device git path on hlc-501: clone repo, `sudo nixos-rebuild switch --flake .#hlc-501`; document result in `research.md` as `R-013` (RAM limits, OOM behavior)
- [ ] T016 [US5] Rewrite `specs/001-nixos-rpi-cluster/quickstart.md`: SD flash → boot → smoke-test → canary → roll-out; workstation push primary; on-device fallback with caveats
- [ ] T017 [US5] Confirm A2 exit gate: forward+rollback canary passed on one Pi4 + one Pi5; on-device result in `research.md`

---

## Phase B: Static IPs + SSH Host Key Inventory [US1]

**Goal**: Declare static IPs in Nix; collect SSH host pubkeys for future sops-nix.

**Independent Test**: All 9 nodes reachable on static IPs; `data-model.md` has host pubkeys.

- [ ] T018 [US1] Add `networking.interfaces.eth0.ipv4.addresses`, `defaultGateway`, `nameservers` inline to `hosts/hlc-501/configuration.nix`; canary deploy + smoke-test
- [ ] T019 [US1] Roll static IP config to `hosts/hlc-401/configuration.nix` and `hosts/hlc-502`–`hosts/hlc-508/configuration.nix` (one-at-a-time canary); smoke-test after each
- [ ] T020 [US1] Collect `ssh_host_ed25519_key.pub` from each node; run `ssh-to-age`; populate SSH host key + age pubkey columns in `specs/001-nixos-rpi-cluster/data-model.md`
- [ ] T021 [US1] Confirm B exit gate: all 9 nodes reachable on static IPs; pubkeys in `data-model.md`

---

## Phase C: Layered Module Reintroduction [US3, US4]

**Goal**: Reintroduce `operator.nix`, `utilities.nix`, MOTD, SSH hardening, ecto-1 stub; retire W-001.

**Independent Test**: All 9 nodes pass smoke-test after each module; dry-run passes for hlc-402/403/404.

- [ ] T022 [US3] Create `modules/users/operator.nix` parameterized by username; import in `hosts/hlc-501/configuration.nix`; canary + smoke-test; roll to all 9 nodes
- [ ] T023 [US4] Create `modules/shell/utilities.nix` (sysadmin packages + `syshelp` command); canary on hlc-501 + smoke-test; roll to all 9 nodes
- [ ] T024 [US4] Create `modules/motd/default.nix` (parameterized) + `modules/cluster/hlc/motd.nix` (HLC ASCII banner + Bob Ross quote); canary on hlc-501 + smoke-test; roll to all 9 nodes
- [ ] T025 [US4] Write `docs/syshelp-reference.md` — categorized markdown reference of installed CLI tools with one-line descriptions
- [ ] T026 [US4] Add SSH hardening to `hosts/hlc-501/configuration.nix` (separate canary cycle); roll to all 9 nodes; smoke-test each
- [ ] T027 [US3] Create ecto-1 stub modules in `modules/cluster/ecto-1/` (hostname-only banner placeholder); add ecto-1 host stubs to `flake.nix`; verify `nixos-rebuild dry-run` evaluates without errors
- [ ] T028 [US3] Remove W-001 from `WORKAROUNDS.md` (Principle III deferral exit condition met)
- [ ] T029 Run `nixos-rebuild dry-run --flake .#hlc-402`, `.#hlc-403`, `.#hlc-404`; confirm all evaluate cleanly
- [ ] T030 Confirm C exit gate: all 9 work-set nodes smoke-test green; decommissioned-set dry-runs pass

---

## Phase D+: Deferred

Phase D (disko / USB RAID1 / sops-nix) and Phase E (k3s / ArgoCD / Longhorn) deferred.
Run `/speckit-plan` after C exits green to detail Phase D.

---

## Dependencies

```
A0 → A1 → A2 → B → C
```

Within A1, T008–T010 parallelizable (separate node pairs).

## MVP Scope

A0 through A2 = minimal viable cluster baseline. B and C build on it.
