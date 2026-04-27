# Tasks: NixOS RPi Cluster — Shell Baseline & Update Loop

**Input**: `specs/001-nixos-rpi-cluster/plan.md` (Phases A0–A2)
**Scope**: Usable shell environment + basic update loop on all work-set nodes.
**User Stories covered**: US4 (Consistent Shell, P3 — promoted to immediate priority),
US1 partial (Provision baseline, P1 — update path validation).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[US4]**: Consistent Shell Environment story
- **[US1]**: Provision Cluster Nodes story (update loop tasks)

---

## Phase 1: Setup (Blocking Infrastructure)

**Purpose**: Populate the IP inventory file that `make smoke-test-all` and `make ip` depend on.

- [ ] T001 Populate `docs/cluster-ips.txt` — create tab-separated file (hostname TAB ip TAB mac): `hlc-401`, `hlc-501` through `hlc-508`. MACs discoverable from Unifi DHCP leases. Verify `make ip HOST=hlc-501` prints `10.23.50.51`.

**Checkpoint**: `make ip HOST=hlc-501` returns `10.23.50.51`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Get hlc-401 reachable and capture the silicon PS1 reference before shell work begins.

⚠️ **CRITICAL**: US4 shell deployment cannot proceed without hlc-401 reachable (T002) and silicon PS1 target captured (T003).

- [ ] T002 Triage hlc-401 unreachability — check Unifi DHCP for any lease from the Pi4 MAC; if on wrong IP confirm DHCP reservation maps MAC to `10.23.50.41`. Check in order: (1) Unifi DHCP leases for unknown MAC acquiring a different IP, (2) `make build HOST=hlc-401` confirms Pi4 image builds clean, (3) reflash with `make build-image HOST=hlc-401 && make flash-image HOST=hlc-401 DEV=/dev/sdX` if needed. Exit: `make smoke-test HOST=hlc-401 IP=10.23.50.41` passes.

- [ ] T003 Capture silicon PS1 format — SSH into silicon as eaglerock; run `echo "$PS1"` and `echo "$PROMPT_COMMAND"`. If PS1 is set in `~/.bashrc` rather than via NixOS `promptInit`, also run `grep -A5 PS1 ~/.bashrc`. Record visual structure (colors, bracket style, git branch indicator, exit-code coloring) in `specs/001-nixos-rpi-cluster/research.md` under a new section `## R-012: Silicon PS1 Reference`. The cluster prompt will replicate this structure with `bob@<hostname>` substituted for `eaglerock@silicon`.

**Checkpoint**: hlc-401 passes smoke-test; R-012 added to research.md.

---

## Phase 3: US4 — Consistent Shell Environment (P3)

**Goal**: All 9 work-set nodes have a correctly-rendered PS1 matching silicon's visual
style, with standard bash history settings and aliases from `modules/shell/common.nix`.

**Independent Test**: SSH into any work-set node as bob; confirm colored prompt renders
without literal `[033[` escape codes; confirm `ll`/`la` aliases work; confirm Up/Down
arrow keys navigate history.

### Fix `prompt.nix` (blocks all US4 deployments)

- [ ] T004 [US4] Fix `modules/shell/prompt.nix` — two bugs to fix: (1) replace all `\033[` occurrences with `\e[` in color variable definitions (bash PS1 interprets `\e` as ESC; `\033` is not interpreted); (2) remove wrapping double-quotes from each color variable value, e.g. `reset = ''"\[\e[0m\]"''` → `reset = ''\[\e[0m\]''`. Update the `hostColor` option default to use `\e[` syntax. After edit, verify the `promptInit` PS1 string interpolates correctly without extra quote characters. Reference R-012 (T003) to choose the correct `hostColor` default that matches silicon's hostname color.

- [ ] T005 [US4] Validate `prompt.nix` fix — run `make dry-run HOST=hlc-501` (eval check), then `make build HOST=hlc-501` (full closure build). Both must exit 0 before proceeding to canary.

- [ ] T006 [US4] Canary: deploy fixed `prompt.nix` + `common.nix` to hlc-501 — add `imports = [ ../../modules/shell/common.nix ../../modules/shell/prompt.nix ];` to `hosts/hlc-501/configuration.nix`; run `make canary HOST=hlc-501 IP=10.23.50.51`. After canary green: `ssh bob@hlc-501.marks.dev` manually; confirm PS1 shows colors without literal `[033[`, `ll` works, Up arrow cycles history, `exit` returns cleanly.

**Checkpoint (US4 canary gate)**: hlc-501 interactive SSH shows clean colored prompt.

### Add shell module imports to remaining work-set configs

T007–T014 are code-only edits (no deployment). They can run in parallel — different files.

- [ ] T007 [P] [US4] Add shell module imports to `hosts/hlc-401/configuration.nix` — add `imports = [ ../../modules/shell/common.nix ../../modules/shell/prompt.nix ];`. If Pi4 vs Pi5 should have different `hostColor`, set `shell.prompt.hostColor` option for hlc-401 (e.g. `"\\\[\\e[33m\\]"` for yellow to distinguish control plane from workers — confirm against R-012 preference).

- [ ] T008 [P] [US4] Add shell module imports to `hosts/hlc-502/configuration.nix` — `imports = [ ../../modules/shell/common.nix ../../modules/shell/prompt.nix ];`.

- [ ] T009 [P] [US4] Add shell module imports to `hosts/hlc-503/configuration.nix` — same as T008.

- [ ] T010 [P] [US4] Add shell module imports to `hosts/hlc-504/configuration.nix` — same as T008.

- [ ] T011 [P] [US4] Add shell module imports to `hosts/hlc-505/configuration.nix` — same as T008.

- [ ] T012 [P] [US4] Add shell module imports to `hosts/hlc-506/configuration.nix` — same as T008.

- [ ] T013 [P] [US4] Add shell module imports to `hosts/hlc-507/configuration.nix` — same as T008.

- [ ] T014 [P] [US4] Add shell module imports to `hosts/hlc-508/configuration.nix` — same as T008.

- [ ] T015 [US4] Eval-check all 12 hosts — `make dry-run-all`; all 12 (including decommissioned-set hlc-402–404) must pass. Fix any eval errors before deployments.

### Deploy shell modules to hlc-401 (Pi4 canary)

- [ ] T016 [US4] Canary: deploy shell modules to hlc-401 — `make canary HOST=hlc-401 IP=10.23.50.41`; after green: `ssh bob@hlc-401.marks.dev`, verify PS1 renders and any Pi4-specific hostColor shows correctly.

### Deploy to remaining Pi5 workers (parallel after T016)

T017–T023 can run in parallel — hlc-501 (T006) and hlc-401 (T016) are proven canaries.

- [ ] T017 [P] [US4] Deploy hlc-502 — `make canary HOST=hlc-502 IP=10.23.50.52`; `make smoke-test HOST=hlc-502 IP=10.23.50.52`.

- [ ] T018 [P] [US4] Deploy hlc-503 — `make canary HOST=hlc-503 IP=10.23.50.53`; smoke-test.

- [ ] T019 [P] [US4] Deploy hlc-504 — `make canary HOST=hlc-504 IP=10.23.50.54`; smoke-test.

- [ ] T020 [P] [US4] Deploy hlc-505 — `make canary HOST=hlc-505 IP=10.23.50.55`; smoke-test.

- [ ] T021 [P] [US4] Deploy hlc-506 — `make canary HOST=hlc-506 IP=10.23.50.56`; smoke-test.

- [ ] T022 [P] [US4] Deploy hlc-507 — `make canary HOST=hlc-507 IP=10.23.50.57`; smoke-test.

- [ ] T023 [P] [US4] Deploy hlc-508 — `make canary HOST=hlc-508 IP=10.23.50.58`; smoke-test.

- [ ] T024 [US4] Full work-set smoke-test — `make smoke-test-all`; all 9 work-set nodes exit 0. This is the US4 phase exit gate.

**Checkpoint (US4 complete)**: `make smoke-test-all` green; interactive SSH on any node shows clean colored PS1.

---

## Phase 4: US1 — Basic Update Loop (P1 partial)

**Goal**: Validate both update paths (workstation push primary, on-device git fallback),
document per-model limits, and provide a bootstrap script for on-device self-provisioning.

**Independent Test**: Forward+rollback canary cycle completes on one Pi4 and one Pi5;
on-device `nixos-rebuild` attempted and result documented.

### Workstation push validation

- [ ] T025 [US1] Validate forward+rollback cycle on hlc-401 (Pi4) — add a trivial comment to `hosts/hlc-401/configuration.nix`; `make canary HOST=hlc-401 IP=10.23.50.41`; then `make rollback HOST=hlc-401 IP=10.23.50.41`; then `make canary` again to restore. Node must remain reachable at every step.

- [ ] T026 [P] [US1] Validate forward+rollback cycle on hlc-501 (Pi5) — same procedure on `hosts/hlc-501/configuration.nix` at IP `10.23.50.51`.

### On-device git workflow

- [ ] T027 [P] [US1] Create `scripts/bootstrap-ondevice.sh` — POSIX shell script accepting one arg (repo URL). Logic: if `/home/bob/nix-config` exists, `git -C /home/bob/nix-config pull`; else `git clone <url> /home/bob/nix-config`. Then `sudo nixos-rebuild switch --flake /home/bob/nix-config#$(hostname)`. Print clear start/finish banners. Make executable (`chmod +x scripts/bootstrap-ondevice.sh`).

- [ ] T028 [US1] Test bootstrap script on hlc-501 — `scp scripts/bootstrap-ondevice.sh bob@hlc-501.marks.dev:/tmp/` then `ssh bob@hlc-501.marks.dev 'bash /tmp/bootstrap-ondevice.sh <repo-url>'`. Note completion time and whether it succeeds, times out, or OOMs. Record in `specs/001-nixos-rpi-cluster/research.md` under new section `## R-013: On-Device Rebuild (Pi5 hlc-501)`: peak `free -m` output, elapsed time, pass/fail.

- [ ] T029 [US1] Test on-device dry-run on hlc-401 (Pi4) — `ssh bob@hlc-401.marks.dev 'git clone <repo-url> /tmp/nix-config && sudo nixos-rebuild dry-run --flake /tmp/nix-config#hlc-401'`. Record result in `research.md` under `## R-013` addendum for Pi4: note if full `switch` is feasible (likely RAM-constrained) or if dry-run-only is the practical limit on Pi4.

**Checkpoint (US1 update loop complete)**: Forward+rollback validated on both Pi models; R-013 documents on-device capability.

---

## Phase 5: Polish & Documentation

- [ ] T030 Rewrite `specs/001-nixos-rpi-cluster/quickstart.md` — reflect current post-A2 state: (1) what's online now; (2) workstation push as primary update path (`make canary` + `make rollback`); (3) on-device git workflow via `scripts/bootstrap-ondevice.sh` with caveats from R-013; (4) direct SSH via `ssh bob@<hostname>.marks.dev` (no Makefile target); (5) remove outdated A0 ssh-hang triage section; (6) update Make targets table.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (T001)**: No dependencies — start immediately.
- **Phase 2 (T002, T003)**: No dependencies — run in parallel with T001.
- **Phase 3**: T004 requires T003 (silicon PS1 reference). T005 requires T004. T006 requires T005. T007–T014 require T006 green. T015 requires T007–T014. T016 requires T015. T017–T023 require T016; run in parallel with each other. T024 requires T017–T023.
- **Phase 4**: Requires T024 (Phase 3 exit gate). T025, T026, T027 run in parallel. T028 requires T027. T029 requires T027.
- **Phase 5**: Requires Phase 4 complete.

### User Story Dependencies

- **US4 (Phase 3)**: Requires T002 + T003 from Foundational.
- **US1 update loop (Phase 4)**: Requires US4 exit gate (T024).

---

## Parallel Opportunities

### Phases 1+2 (start together)
```
T001 (docs/cluster-ips.txt)  | T002 (hlc-401 triage)  | T003 (silicon PS1)
```

### Phase 3 — config edits after T006 canary (all different files)
```
T007 (hlc-401)  T008 (hlc-502)  T009 (hlc-503)  T010 (hlc-504)
T011 (hlc-505)  T012 (hlc-506)  T013 (hlc-507)  T014 (hlc-508)
```

### Phase 3 — canary deployments after T016 (separate nodes)
```
T017 (hlc-502)  T018 (hlc-503)  T019 (hlc-504)  T020 (hlc-505)
T021 (hlc-506)  T022 (hlc-507)  T023 (hlc-508)
```

### Phase 4 — update loop (independent nodes + file)
```
T025 (hlc-401 cycle)  |  T026 (hlc-501 cycle)  |  T027 (bootstrap script)
```

---

## Implementation Strategy

### MVP: US4 on hlc-501 + hlc-401 only
1. T001–T003 (setup + foundational)
2. T004–T006 (fix prompt → canary hlc-501)
3. T007 + T015–T016 (hlc-401 shell baseline)
4. **STOP and VALIDATE**: two nodes have working PS1

### Full US4 (all 9 work-set nodes)
5. T008–T014 + T017–T024

### Full scope (US4 + US1 update loop)
6. T025–T029 (update path + on-device bootstrap)
7. T030 (quickstart docs)

---

## Notes

- All deployments use `make canary` — never bare `nixos-rebuild switch`.
- hlc-402/403/404 (decommissioned-set): dry-run only, never in canary/deploy tasks.
- If any canary fails: stop, do not proceed to remaining nodes, triage first.
- Connect directly: `ssh bob@<hostname>.marks.dev` — no `make ssh` target.
- W-001 (inline host configs) remains open after these tasks — per-host import declarations are still inline (shared module files, but no shared `mkHlcNode` wrapper). W-001 exits in Phase C when the shared cluster module replaces per-host import lists.
- Total tasks: 31 (T001–T030 + implicit sub-steps). Parallel batches reduce sequential depth to ~10 steps.
