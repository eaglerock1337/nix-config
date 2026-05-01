# Quickstart: NixOS RPi Cluster Foundation (v2)

**Date**: 2026-04-29
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Contracts**: [contracts/](./contracts/)

This is the operator runbook for taking the HLC cluster from the current state (existing 12 host configs on the archived `nix-community/raspberry-pi-nix`, with a working SD baseline only on `main`) to the target state defined by the spec: 9 nodes (`hlc-401`, `hlc-501..508`) running NixOS via the `nvmd/nixos-raspberrypi` fork, with USB-RAID root, NVMe data volume on Pi 5, full operator UX, and k3s OS-level prereqs in place.

The runbook is sequenced by the implementation phases listed in [plan.md](./plan.md) §"Phasing notes (W-001 alignment)". Every cluster-touching step routes through Makefile targets per Constitution Principle VII.

---

## Prerequisites

- Working directory: `/Users/petermarks/src/nix-config` on `gibson` (or equivalent path on whichever build host is in use).
- Branch: `001-nixos-rpi-cluster`. Phase 1 below is the mandatory first step — the running code is reset to `main` while spec-kit / Claude / process context is preserved.
- Hardware on hand: 9 in-scope Pis powered, racked, ethernet-connected; 2 USB-3 drives per node; 1 NVMe per Pi 5; 9 SD cards (16 GB or larger).
- Operator key: `eaglerock@gibson` SSH public key (re-introduced into `flake.nix` as `operatorPubkey` during Phase 1).
- IP convention: `hlc-VNN` → `10.23.50.<octet>` per [contracts/makefile-targets.md](./contracts/makefile-targets.md). No lookup file required.

---

## Phase 1 — Setup: Baseline reset

**Goal**: Bring the running code (`flake.*`, `hosts/silicon`, `hosts/hlc-501`, `home/eaglerock.nix`, `modules/home`, `modules/hosts`, `modules/hardware/x1-carbon.nix`) back to `main`'s working state. Keep spec-kit, Claude context, `WORKAROUNDS.md`, the Makefile build-out, and `scripts/smoke-test.sh`. Delete the failed-attempt-only files (Pi 4 host configs, hlc-502..508 host configs, `modules/{cluster,motd,shell,users}`, `modules/hardware/rpi{4,5}.nix`, debug artifacts, stale `tasks.md`).

The full keep / revert / delete lists and the rationale are in [plan.md → Phase 1 — Setup](./plan.md#phase-1--setup-confirmed-complete). The operator commands:

```bash
# Recovery snapshot.
git tag pre-reset-2026-04-29

# Commit any existing in-progress context changes (spec/plan/research/
# tasks/workflow.md/WORKAROUNDS.md edits made during plan/clarify/analyze)
# so they survive the reset and land as their own commit before Phase 0.

# Restore main's running code (including the minimal Makefile).
git checkout main -- \
    flake.nix flake.lock Makefile \
    hosts/silicon hosts/hlc-501 \
    home/eaglerock.nix \
    modules/home modules/hosts modules/hardware/x1-carbon.nix

# Delete failed-attempt-only files.
git rm -r \
    hosts/hlc-401 hosts/hlc-402 hosts/hlc-403 hosts/hlc-404 \
    hosts/hlc-502 hosts/hlc-503 hosts/hlc-504 hosts/hlc-505 \
    hosts/hlc-506 hosts/hlc-507 hosts/hlc-508 \
    modules/cluster modules/motd modules/shell modules/users \
    modules/hardware/rpi4.nix modules/hardware/rpi5.nix
git rm -f hlc-output.txt lshw-output.txt

# Add hlc-output.txt / lshw-output.txt to .gitignore if not already.

git commit -m "Phase 0: baseline reset — running code to main, context kept"
```

**Validation gate** — all four MUST pass before proceeding to the upstream swap:

1. `make silicon-dry` — silicon evaluates (target exists on `main`).
2. `make build-image HOST=hlc-501` — Pi 5 SD image builds. Still on `raspberry-pi-nix`; nvmd swap is Phase 1.
3. `make flash-image HOST=hlc-501 DEV=/dev/sdX` — image flashes.
4. Insert SD into `hlc-501`, power on. Remove known_hosts entries for `10.23.50.51` and `hlc-501`, then run `ssh bob@10.23.50.51 uname -a` and `ssh bob@hlc-501 uname -a` — both MUST succeed (no `-t`; PTY mode caused Pi login hangs during testing). (`make smoke-test` is added in Phase 1; this manual SSH check is the gate before it exists.)

On green: proceed to the upstream swap. Open issues blocking the gate get fixed first; Constitution VIII forbids assuming around an unexplained failure.

After the baseline reset, the branch's running code is identical to `main`, the spec/plan/research/etc. are intact, and the next commit starts fresh on the nvmd swap.

---

## Phase 1 (cont.) — Upstream swap + single-host Makefile targets

**Goal**: Replace `nix-community/raspberry-pi-nix` with `nvmd/nixos-raspberrypi` as the upstream Pi NixOS source. Re-introduce `flake.nix` helpers (`mkHlcNode`, `operatorPubkey`, `disko` / `nixos-anywhere` / `sops-nix` inputs). Add the four single-host Makefile targets (`dry-run`, `build`, `smoke-test`, `ip`) that every later phase's safety gate uses. Validate `hlc-501` boots from the new SD image. (Research: R-001.)

1. Update `flake.nix`:
   - Remove `raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";`.
   - Add `nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";` (verify exact input name + module export names against the nvmd fork's current `README.md`).
   - Re-add the `operatorPubkey` constant and the `mkHlcNode` helper.
   - Add `disko`, `nixos-anywhere`, `sops-nix` flake inputs (used in later phases; sops-nix usage deferred per W-002).
2. `nix flake update` — re-lock; commit `flake.nix` + `flake.lock` together.
3. Add Phase 1 Makefile targets: `make dry-run HOST=<host>`, `make build HOST=<host>`, `make smoke-test HOST=<host>`, `make ip HOST=<host>` (HOST→IP derivation per the convention).
4. Validation: `make build HOST=hlc-501` succeeds; `make build-image HOST=hlc-501` succeeds.
5. Flash: `make flash-image HOST=hlc-501 DEV=/dev/sdX`.
6. Insert SD into `hlc-501`, power on. After ~5 minutes:
   - `make smoke-test HOST=hlc-501` — green (IP derived as `10.23.50.51`).
   - SSH manually: `ssh bob@hlc-501.marks.dev`. Confirm hostname, kernel, basic shell access.
7. **Phase exit gate**: `hlc-501` boots on the nvmd fork, accepts SSH as `bob`, smoke-test green. Tag the commit (`git tag phase1-nvmd-swap`) for `git bisect` recovery.

---

## Phase 3 — SD Bootstrap Rebuild (US1, FR-002..FR-004)

**Goal**: SD bootstrap configuration is barebones (bob + key + recovery utils + DHCP) and physically separated from per-host service modules. Stale-image bug (post-mortem root cause) is closed by the derivation closure correctly depending on the bootstrap source. (Research: R-006, R-010.)

1. Create `modules/sd/bootstrap.nix` and `modules/sd/recovery-utils.nix` per [research.md R-010](./research.md).
2. Wire the SD-image module set in `flake.nix` (and/or the cluster scope) to import only `modules/sd/*` for the SD image build path; per-host service modules MUST be excluded from the SD image's module list.
3. Add a `REBUILD=1` opt-in to `make build-image` that passes `--rebuild` through to `nix build`.
4. Validate the cache invariant: change a comment in `modules/sd/bootstrap.nix`, run `make build-image HOST=hlc-501` (no `REBUILD`), confirm the output hash differs from the prior build.
5. Flash the rebuilt SD on `hlc-501`; run `make smoke-test HOST=hlc-501` after boot.
6. **Phase exit gate**: bootstrap SD smaller than current image (per FR-003), boots, smoke-test green; `make build-image` honors source changes without `REBUILD=1`.

---

## Phase 4 — Per-Host Scaffolding (US2, FR-005..FR-009)

**Goal**: All 12 host configurations dry-run from a clean checkout. Module layering (`cluster/common.nix` → `cluster/hlc/*` → `hardware/rpi{4,5}.nix` → `hosts/<host>/`) is in place. (Research: R-008.)

1. Stand up `modules/cluster/common.nix` skeleton — minimal set: shell baseline, toolbox import, MOTD wiring, sshd posture. (Service-level modules added in later phases; this is the structural skeleton.)
2. Refactor `modules/cluster/hlc/hosts.nix` to consume `cluster/common.nix`; HLC-specific options (operator user, MOTD banner, FQDN convention) override here.
3. Validate all 12 hosts dry-run from clean: `make dry-run HOST=hlc-401`, `make dry-run HOST=hlc-501`, ... `make dry-run HOST=hlc-508`. The deferred set (`hlc-402..404`) MUST also dry-run cleanly.
4. **Phase exit gate**: SC-002 satisfied — all 12 evaluate. SC-003 testable — adding a stub `hlc-509` host should require ≤2 file changes. Tag commit.

---

## Phase 5 — Disko + nixos-anywhere (US3, FR-010..FR-014)

**Goal**: Provisioning workflow installs the full per-host configuration onto USB-RAID + NVMe. (Research: R-004, R-005, R-007.)

1. Add `disko/rpi4.nix` and `disko/rpi5.nix` per [research.md R-004](./research.md). Use `/dev/disk/by-id/` paths, parameterized via NixOS module arguments.
2. Set `BOOT_ORDER = 0xf14` on each in-scope Pi via `rpi-eeprom-config` from a one-shot service in `modules/hardware/rpi-eeprom.nix`. (Run on first boot of the SD baseline; idempotent thereafter.)
3. Add `make provision HOST=<host>` target wrapping `nixos-anywhere`.
4. Provision `hlc-501`: `make provision HOST=hlc-501`. Confirm the node reboots into the new root, `/` is on the mdadm array, `/srv/ssd` is on NVMe, `/srv/usb` is mounted; `make smoke-test HOST=hlc-501` green.
5. Recovery test (FR-011, SC-005): power down `hlc-501`, physically detach both USB drives, power up. Confirm SD recovery environment loads with `mdadm` available; `make smoke-test HOST=hlc-501` against the recovery environment also passes.
6. Re-attach USB drives, power cycle. Confirm normal boot resumes.
7. Provision the remaining work-set serially: `make provision HOST=hlc-502` … `hlc-508`, then `hlc-401`. One node at a time; `make smoke-test HOST=<host>` after each. (No `make provision-all` wrapper — operator runs the loop manually; cluster-wide automation is out of scope.)
8. **Phase exit gate**: 9 nodes provisioned; SC-005 verified for at least one Pi 5 and `hlc-401`. Tag commit.

---

## Phase 6 — Operator UX (US4, FR-015..FR-020)

**Goal**: HLC MOTD, two-form PS1 (local + remote), sysadmin toolbox, modular home-manager all in place. Reintroduced one module at a time per W-001's exit plan. (Research: R-002, R-009.)

This phase is also where `make update-node HOST=<host>` and `make rollback HOST=<host>` are added (first phase that does live-node config rollouts post-provisioning). Per-module rollout pattern, repeated for each module in the order below:

1. Apply the new module to `hlc-501`: `make update-node HOST=hlc-501`.
2. `make smoke-test HOST=hlc-501` — must be green.
3. If smoke-test fails: `make rollback HOST=hlc-501`, diagnose, fix, retry.
4. On green canary: serially run `make update-node HOST=<host>` + `make smoke-test HOST=<host>` for each remaining work-set node (`hlc-502..508`, then `hlc-401`).

Module reintroduction order (W-001 exit plan):

1. **Add Makefile targets**: `make update-node HOST=<host>`, `make rollback HOST=<host>`. These wrap `sudo nixos-rebuild switch --flake .#<host> --target-host bob@<ip> --use-remote-sudo` and `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<ip> --use-remote-sudo` respectively, with HOST→IP derivation.
2. **Toolbox** (`modules/shell/utilities.nix`) — alphabetical packages with inline rationale. Land first because every later module imports it. Apply per the rollout pattern above.
3. **Bash baseline** (`modules/shell/common.nix`) — sets bash as canonical shell, baseline aliases.
4. **PS1** (`modules/shell/prompt.nix`) — local form (silicon-style, color preserved, `////` → `☁⛰☁`); remote form (two-line box-drawing per `remote-ps1.txt`, no color, FQDN). Mountain-glyph presentation strategy from R-002 (variation-selector default; ASCII fallback option). Manually validate rendering on kitty + plain `xterm-256color` SSH + `TERM=xterm` SSH per the R-002 follow-up.
5. **MOTD** (`modules/motd/default.nix`) — parameterized banner module; HLC banner matches post-mortem reference exactly.
6. **Operator user** (`modules/users/operator.nix`) — bob with hardcoded authorized key (W-002 + W-003 sites annotated), passwordless wheel (W-002), key-only sshd planned for the SSH-hardening sub-step (W-003 close).
7. **Home-manager modular split** — `modules/home/{base,server,workstation}.nix` per R-009; per-user entry points compose them. Apply to silicon (workstation profile) via `make silicon-switch`; apply to `hlc-501` (server profile) per the rollout pattern, then roll to the rest of the work-set.
8. **SSH hardening** (`services.openssh.settings.PasswordAuthentication = false` + `KbdInteractiveAuthentication = false`) — closes W-003. Apply per the rollout pattern; verify key-only login still works after each switch.
9. **Phase exit gate**: SC-006 verified — SSH as bob into any cluster node lands in the styled bash session with the HLC MOTD and the toolbox; SSH as eaglerock into silicon lands in the same toolbox without the HLC MOTD. W-001 + W-003 marked Resolved. Tag commit.

---

## Phase 7 — k3s Prerequisites (US5, FR-021..FR-023)

**Goal**: Every in-scope node has k3s, k9s, container runtime, kernel/sysctl prereqs installed. The k3s service unit is enabled but stopped, with no cluster state on disk. (Research: R-003.)

1. Create `modules/k8s/prereqs.nix` per R-003: `services.k3s.enable = true`, `systemd.services.k3s.wantedBy = lib.mkForce [ ];`, container runtime deps, kernel modules, sysctls, k9s package, `k` shell alias.
2. Import the module from `modules/cluster/common.nix` (so all cluster nodes inherit).
3. Apply to `hlc-501`: `make update-node HOST=hlc-501` → `make smoke-test HOST=hlc-501`. Verify `k3s --version`, `k9s --version`, `k version --client` succeed; `systemctl is-enabled k3s` reports enabled, `systemctl is-active k3s` reports `inactive`.
4. Roll to remaining work-set serially: for each of `hlc-502..508` then `hlc-401`, run `make update-node HOST=<host>` + `make smoke-test HOST=<host>`.
5. **Phase exit gate**: SC-007 verified — packages and prereqs present on all 9 work-set nodes; service enabled but stopped; no cluster state on disk. Tag commit.

---

## Closing

- All 9 work-set nodes are now in the target state. The 3 deferred Pi 4s (`hlc-402..404`) remain on the old Debian cluster, untouched, with evaluable but unflashed NixOS configs in this repo.
- Open ledger entries: W-001 (closes when all six modules reintroduce per Phase 6), W-002 (closes with the future secrets-mgmt feature spec), W-003 (closes with `services.openssh.settings.PasswordAuthentication = false` in a future hardening pass).
- The follow-on cluster-bootstrap spec begins from this state: it flips `wantedBy` back to `[ "multi-user.target" ]`, drops k3s configuration onto each node, and brings the cluster up. No reflashing required.
- If anything during Phases 3–7 surprises you (a node misbehaves, an upstream module name changed, a glyph renders wrong), apply Constitution Principle VIII: state the conflict explicitly, ask for the data point that would disambiguate, do not silently rewrite the working theory.
