# Implementation Plan: NixOS RPi Cluster Foundation — RESET

**Branch**: `001-nixos-rpi-cluster` | **Date**: 2026-04-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-nixos-rpi-cluster/spec.md`

> **Plan reset 2026-04-26.** Previous plan attempted to land shared modules
> (operator/shell/MOTD), 12 host configs, network static IPs, and SSH hardening
> in a single Phase A push. Result: hlc-501 booted but interactive SSH hangs at
> login; hlc-508 never came back on the network after a debug revert. These
> nodes are headless rack-mounted Pi5s — no console, no keyboard, no monitor.
> A node that won't accept SSH is bricked until it's physically pulled out.
>
> This plan throws out the previous Phase A. We rebuild on the **known-good
> main-branch shape** (the b357c6d POC: 7-line host config, no shared modules,
> just `raspberry-pi-nix.board`, hostname, DHCP, openssh, bob user with key,
> stateVersion). Every additional feature is added **one at a time, to one
> canary node, validated remotely, before rolling to the rest**. Pre-deploy
> validation is a hard gate.
>
> Out of scope for this reset: shell modules, MOTD, operator parameterization,
> disko/USB-RAID, sops-nix, k3s, ArgoCD, Longhorn. Those return in Phase C+
> only after all 12 nodes are reliably reachable and remotely updatable.

## Summary

Get all 12 HLC nodes (4× Pi4 control plane + 8× Pi5 workers) booted on SD card,
on the network, accepting `ssh bob@host` interactively *and* `nixos-rebuild
switch --target-host` remotely. Stop there. Defer every other concern (shared
modules, RAID, secrets, k3s, GitOps) to later phases gated on a stable
remotely-updatable baseline.

The technical approach is regression-driven: replicate the main-branch hlc-501
config shape (proven to boot and ssh) across all 12 hosts, validate locally
before flashing, deploy to one canary first, then roll to the rest. Only after
all 12 are reachable do we begin layering shared modules in — one module, one
canary, one rollout, one validation cycle at a time.

## Technical Context

**Language/Version**: Nix (flakes), NixOS 25.11 stable, aarch64-linux for Pi nodes; build host gibson is x86_64-linux with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`.
**Primary Dependencies**: `nixpkgs/nixos-25.11`, `raspberry-pi-nix` (archived 2025-03; pinned), `nixos-hardware` (Pi5 module), `home-manager` (silicon only). `disko`, `sops-nix`, `nixos-anywhere` deferred to Phase C+.
**Storage**: SD card boot only for this plan. USB-RAID1 root and Pi5 NVMe (Longhorn) deferred.
**Testing**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (full evaluation + build) as the pre-deploy gate. `make dry-run-all` for cheap eval-only check across all 12. Post-deploy smoke: `ssh -o BatchMode=yes -o ConnectTimeout=10 bob@<ip> true` plus an interactive-shell test (`ssh bob@<ip>` to a real PTY, must reach prompt within 5s).
**Target Platform**: 12× Raspberry Pi (4× Pi4 / bcm2711 / hlc-401–404, 8× Pi5 / bcm2712 / hlc-501–508), headless, rack-mounted, no console access. Build host: gibson (Ryzen 9 5950X, NixOS).
**Project Type**: NixOS configuration repo (flake-based). Existing `hosts/silicon` (laptop) is unrelated to this feature and unchanged.
**Performance Goals**: N/A — correctness/reachability gating only. Image build time tolerable up to ~30 min/model under qemu-aarch64.
**Constraints**:
- **No console access.** Every change MUST be remotely recoverable. Configs that compile but break sshd at runtime brick the node.
- **No bundled experiments.** One change per deploy; canary first; smoke test before rolling to remaining nodes.
- **Pre-deploy build gate.** Never push a config that has not at minimum eval-passed `dry-run`. For the canary node, full `nix build ... .toplevel` must pass.
- **Rollback path.** `nixos-rebuild switch --rollback --target-host` must work, which means the previous generation must be the last good config — never leave a node on a broken generation as "current."
**Scale/Scope**: 12 cluster nodes, all aarch64, single subnet `10.23.50.0/24`. Existing Debian cluster (hlc-301–308 + hlc-401–404 Debian) remains in production during cutover.

## Constitution Check

*GATE: Must pass before Phase 0. Re-check after Phase 1.*
*Aligned to constitution v1.1.0.*

| Principle | Status | Notes |
|---|---|---|
| I. Declarative Configuration | ✅ | All host config in nix; no imperative drift permitted. |
| II. Reproducibility via Flakes | ✅ | `flake.lock` pins every input incl. archived `raspberry-pi-nix`. |
| III. Modular Design | ⚠️ deferred (legal under Principle V) | Shared modules deferred to Phase C. Phase A intentionally inlines the minimal config in each `hosts/<name>/configuration.nix` — the previous attempt to land modules + 12 hosts simultaneously is what broke ssh. Modules return one at a time in Phase 7. Logged as workaround W-NNN in `WORKAROUNDS.md` (to be created at T017); exit condition = Phase 7 complete. |
| IV. Safety-First Changes | ✅ (strengthened) | Adds canary deployment + interactive-ssh smoke test on top of dry-run. Constitution v1.1.0 elevates this to a non-negotiable canary requirement during transition. |
| V. Pragmatic Phasing | ✅ | Phase A workarounds (passwordless `wheel`, deferred `PasswordAuthentication = false`, inline host configs vs Principle III) all eligible for `WORKAROUNDS.md` ledger entries with exit conditions tied to Phases 7a / 7f. |
| VI. Minimal & Explicit Footprint | ✅ | Phase A footprint is intentionally tiny. No new unfree pkgs. |
| Cluster Topology section | ⚠️ scope correction needed | Plan currently treats all 12 hosts uniformly. Constitution v1.1.0 § Cluster Topology defines work-set (hlc-401, hlc-501–508 = 9 hosts) and decommissioned-set (hlc-402–404 = Debian, untouchable). Plan + tasks need scope edit: build/flash/canary tasks restricted to work-set; hlc-402–404 host configs may exist in flake (dry-run OK) but no flash/switch invocation until a future decommission phase. |

**Result: PASS with two justified deferrals (Principle III via Principle V; topology scope correction queued as plan/tasks edit).**

## Project Structure

### Documentation (this feature)

```text
specs/001-nixos-rpi-cluster/
├── plan.md              # This file (reset 2026-04-26)
├── research.md          # Existing — still valid for Phase C+ tech choices
├── data-model.md        # Existing — node IPs/MACs/age keys reference
├── quickstart.md        # MUST be revised to match this reset (Phase A1 task)
├── contracts/           # N/A for an internal config repo
├── checklists/
│   └── requirements.md  # Existing
└── tasks.md             # Will be regenerated by /speckit-tasks against this plan
```

### Source Code (repository root)

```text
flake.nix                       # Single source for all 13 nixosConfigurations (silicon + 12 HLC)
Makefile                        # build-image, flash-image, dry-run, dry-run-all, update-node, smoke-test, canary-deploy

hosts/
├── silicon/                    # Unchanged — operator's laptop
│   ├── configuration.nix
│   └── hardware-configuration.nix
├── hlc-401/configuration.nix   # Pi4 control plane × 4 — minimal Phase A config
├── hlc-402/configuration.nix
├── hlc-403/configuration.nix
├── hlc-404/configuration.nix
├── hlc-501/configuration.nix   # Pi5 worker × 8 — minimal Phase A config
├── hlc-502/configuration.nix
├── hlc-503/configuration.nix
├── hlc-504/configuration.nix
├── hlc-505/configuration.nix
├── hlc-506/configuration.nix
├── hlc-507/configuration.nix
└── hlc-508/configuration.nix

modules/
├── home/                       # Unchanged silicon home-manager modules
├── hardware/
│   └── x1-carbon.nix           # Unchanged silicon hardware
# NO modules/cluster/, modules/shell/, modules/motd/, modules/users/ in Phase A.
# These directories may exist (from prior commits) but are not imported by any
# Phase A host config. They are ignored until Phase C, then re-evaluated one
# at a time per the layered-reintroduction process below.

scripts/
└── smoke-test.sh               # NEW: interactive-ssh + nixos-rebuild dry-run round-trip
```

**Structure Decision**: Keep the existing flake-per-host pattern from main. Phase A
intentionally has zero shared cluster modules — every HLC host file is a near-clone of
the main-branch hlc-501 (≈10 lines) parameterized only by hostname and (for Pi4 nodes)
board ID. Duplication is the point: it makes "what changed" unambiguous and isolates
blast radius when something breaks. Shared modules return in Phase C only after the
unmodified-baseline cluster is provably reachable and remotely updatable.

## Phases

### Phase A0 — Triage (no new feature work; recover bricked nodes)

**Goal**: Get hlc-508 back on the network and hlc-501 accepting interactive SSH.

A0 is purely a recovery exercise. No spec/feature work overlaps with it.

1. **Reproduce ssh-hang on a non-bricked node.** Boot a fresh SD with the
   *current* branch hlc-501 config in a spare Pi or qemu-aarch64 VM
   (`nixos-rebuild build-vm --flake .#hlc-501`). Observe the ssh-login
   behavior end-to-end without risking another rack node.
2. **Diff against main.** `git diff main..HEAD -- hosts/hlc-501/configuration.nix
   modules/users/operator.nix modules/shell/ modules/motd/`. Identify which
   added line first introduces the hang. Candidates per current diffs:
   - SSH `ClientAliveInterval`/`MaxStartups` block in `modules/users/operator.nix`
     (already removed on the working copy — confirm whether removal is what
     killed hlc-508 or coincidental).
   - `programs.bash.promptInit` / `PROMPT_COMMAND` in `modules/shell/prompt.nix`
     (a shell-startup hang would manifest exactly as "auth succeeds, prompt
     never arrives").
   - `__git_ps1` source not present at PS1 setup time.
   - MOTD content (large `etc/motd` is benign; a script in `dynamic-motd`
     blocking would not be).
3. **Recover hlc-508.** Pull SD, reflash with the **main-branch hlc-501
   config** renamed to hlc-508 (just `raspberry-pi-nix.board = "bcm2712"`,
   `networking.hostName = "hlc-508"`, `networking.useDHCP = true`, openssh,
   bob user, stateVersion). Power up. Confirm DHCP + interactive ssh.
4. **Recover hlc-501.** Same procedure: reflash with the main-branch
   minimal config under hlc-501 hostname. Confirm reachable.
5. **Document the root cause.** Add a one-paragraph note to
   `specs/001-nixos-rpi-cluster/research.md` under a new section
   `R-XXX: SSH-hang root cause (Phase A0 triage)`. Future module work in
   Phase C must re-test this specific failure mode before merging.

**Exit gate**: All physically present nodes (whatever subset is racked today)
respond to `ping` and `ssh bob@<ip> true` within 10s. Confirmed by running
`make smoke-test HOST=<host>` (added in Phase A1) — or, until that target
exists, manually.

---

### Phase A1 — Baseline (12 minimal host configs + tooling)

**Prerequisites**: A0 complete; ssh-hang root cause known and avoided.

**Goal**: All 12 nodes flake-eval, build, flash, boot, get DHCP lease, accept
interactive ssh, and accept `nixos-rebuild switch --target-host`.

This is the new Phase A. It is intentionally tiny.

1. **Revert host configs to main-branch shape** (per host, parameterized only by
   hostname and board ID). Each `hosts/hlc-NNN/configuration.nix` is ~12 lines:
   ```nix
   { ... }: {
     raspberry-pi-nix.board = "bcm2711";   # or bcm2712 for Pi5
     networking.hostName = "hlc-NNN";
     networking.useDHCP = true;            # Phase A1 uses DHCP reservations only
     services.openssh.enable = true;
     users.users.bob = {
       isNormalUser = true;
       extraGroups = [ "wheel" ];
       openssh.authorizedKeys.keys = [ "<gibson key>" ];
     };
     security.sudo.wheelNeedsPassword = false;
     system.stateVersion = "25.11";
   }
   ```
   No imports. No shared modules. No SSH hardening. No prompt. No MOTD. Static
   IPs deferred — DHCP reservations in Unifi provide stable addressing for now.
2. **flake.nix wiring**: define a single `mkHlcNode` helper that builds an
   aarch64-linux nixosSystem with `raspberry-pi-nix.nixosModules.raspberry-pi`,
   `raspberry-pi-nix.nixosModules.sd-image`, the per-board nixos-hardware module,
   and the host config. No `extraModules` debug paths. Identical for all 12.
3. **Tooling — Makefile additions**:
   - `make dry-run-all` (already exists) — eval-only sanity across all 12.
   - `make build HOST=hlc-NNN` — full toplevel build (catches errors dry-run misses).
   - `make smoke-test HOST=hlc-NNN IP=<ip>` — reachability + interactive-ssh check
     (calls `scripts/smoke-test.sh`).
   - `make canary HOST=hlc-NNN IP=<ip>` — wraps `update-node` with pre-flight
     `make build` and post-flight `make smoke-test` plus auto-rollback on
     smoke-test failure (`nixos-rebuild switch --rollback --target-host`).
4. **scripts/smoke-test.sh** — minimal POSIX shell script. Inputs: `IP`. Steps:
   (a) `ping -c1 -W2 $IP` (b) `ssh -o BatchMode=yes -o ConnectTimeout=10
   bob@$IP true` (c) `timeout 10 ssh -tt bob@$IP "echo HELLO"` to verify a PTY
   session reaches a prompt and exits cleanly. Non-zero on any failure.
5. **Image build + flash** for hlc-401 and hlc-501 (one Pi4, one Pi5). Boot
   each. Run smoke-test. If green, proceed; if red, stop and triage.
6. **Roll to remaining 10 nodes** in pairs (one Pi4 + one Pi5 at a time),
   smoke-testing after each.
7. **Quickstart revision**: rewrite `specs/001-nixos-rpi-cluster/quickstart.md`
   to match Phase A1 reality (current quickstart references shell MOTD that
   does not exist in this plan).

**Exit gate (the only thing that proves Phase A1 done)**:
```
for h in hlc-40{1..4} hlc-50{1..8}; do make smoke-test HOST=$h IP=<ip>; done
```
exits 0 for all 12.

---

### Phase A2 — Remote-update validation

**Prerequisites**: A1 exit gate passes.

**Goal**: Prove `nixos-rebuild switch --target-host` is reliable for every node.
Without this, every Phase B+ change risks a brick.

1. Make a deliberately trivial config change (e.g., add `pkgs.htop` to one
   host's `environment.systemPackages`). Deploy with `make canary HOST=...
   IP=...`. Smoke-test. Roll back. Smoke-test. Confirms `--rollback` works.
2. Repeat for one Pi4 and one Pi5.
3. Document the verified canary loop in `quickstart.md`.

**Exit gate**: At least one Pi4 and one Pi5 have completed a forward + rollback
cycle and remained reachable.

---

### Phase B — Static addressing & SSH host-key inventory (still no modules)

**Prerequisites**: A2 passed.

**Goal**: Move from DHCP-reservation addressing to declared static IPs in nix,
and capture each node's `ssh_host_ed25519_key.pub` for later age-recipient use.

Still no shared modules. Add `networking.interfaces.eth0.ipv4.addresses`,
`networking.defaultGateway`, `networking.nameservers` directly into each host
config. One canary first, smoke-test, roll out.

**Exit gate**: All 12 nodes reachable on their final static IPs; host pubkeys
inventoried in `data-model.md`.

---

### Phase C — Layered module reintroduction (one module at a time)

**Prerequisites**: B passed.

**Goal**: Begin reintroducing the modules from the previous (failed) Phase A —
operator, shell, MOTD — but **one at a time**, each gated by canary + smoke-test.

Process for each module:
1. Add the module file under `modules/`.
2. Import it in **one canary host only** (suggest hlc-404 — last Pi4 server, lowest
   blast radius if it bricks).
3. `make build HOST=hlc-404` — full build must pass.
4. `make canary HOST=hlc-404 IP=...` — deploy + smoke-test + auto-rollback on fail.
5. If green, manual interactive-ssh test from operator workstation: `ssh bob@hlc-404`,
   confirm prompt arrives, `exit` returns cleanly.
6. If still green, roll to remaining 11. Smoke-test all.
7. Commit per module. Never bundle two modules in one commit.

Module order:
1. `modules/users/operator.nix` (parameterized bob user) — but **without** the
   removed `services.openssh.settings` block. SSH hardening is its own later
   step, not bundled.
2. `modules/shell/common.nix` (bash defaults only, no PROMPT_COMMAND).
3. `modules/shell/prompt.nix` (PS1 only, with explicit interactive-ssh test in
   the canary smoke-test — this is the most likely repeat-offender for ssh-hang).
4. `modules/shell/utilities.nix` (sysadmin packages + syshelp).
5. `modules/motd/default.nix` + `modules/cluster/hlc/motd.nix`.
6. SSH hardening (separate step, separate canary cycle).

**Exit gate per module**: all 12 nodes pass smoke-test after rollout.
**Exit gate for Phase C**: all six modules deployed, all 12 nodes green.

---

### Phase D — Disko / USB-RAID root, sops-nix secrets

Deferred. Plan in detail at /speckit-plan time *after* Phase C exits green.

### Phase E — k3s, ArgoCD, Longhorn

Deferred. Plan after Phase D.

## Phase 0: Outline & Research

The existing `research.md` covers raspberry-pi-nix, disko, nixos-anywhere, k3s,
sops-nix, Longhorn, etc. — all still valid for Phases C+. Phase A0/A1/A2 introduces
**no new tech**, so no new research is required.

**One new research note added in Phase A0**: a section `R-XXX: SSH-hang root cause`
recording the specific commit/line/module that caused the Phase-A bricking. This
becomes a regression check for any module reintroduced in Phase C.

**Output**: existing `research.md` augmented with the SSH-hang root-cause section
(work item in Phase A0 step 5).

## Phase 1: Design & Contracts

**Data model**: `data-model.md` already enumerates the 12 nodes, MACs, IPs, age
keys. No change needed for this reset. Phase B will populate the SSH host-key
column once nodes are online.

**Contracts**: N/A — internal config repo, no external interfaces produced by
this feature.

**Quickstart**: rewrite needed (Phase A1 step 7). Existing quickstart describes
the failed Phase A flow with shell MOTD. New quickstart matches this plan's A1
flow: build SD, flash, boot, smoke-test, canary, rollout.

**Agent context update**: this plan file is the new pointer; CLAUDE.md already
references `specs/001-nixos-rpi-cluster/plan.md`, so no link change required.

**Output**: existing `data-model.md` (unchanged), revised `quickstart.md` (Phase
A1 task), augmented `research.md` (Phase A0 task).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Constitution III deferred for Phase A1: 9 work-set host configs duplicate ~12 lines each instead of importing a shared cluster module | The previous attempt to land shared modules + 12 hosts in one push produced a non-recoverable bricked node (hlc-508) and an interactive-ssh hang that does not reproduce in dry-run. Duplicated minimal configs make blast radius zero per-host and let us isolate any future module regression to the exact module being reintroduced. Constitution v1.1.0 Principle V explicitly authorizes this deferral when logged in `WORKAROUNDS.md` with an exit condition. | The "right" Nix idiom (a shared `mkHlcNode` cluster module) is what we just had and what just broke. Restoring it before establishing a working baseline repeats the same mistake. The duplication exists for ~2 phases (A1, A2, B) and is removed module-by-module in Phase 7. Decommissioned-set hosts (hlc-402–404) are not in scope for active rollout — they evaluate in dry-run only. |
| `make canary` adds a non-trivial deploy wrapper (build → switch → smoke-test → auto-rollback) instead of plain `nixos-rebuild switch --target-host` | These nodes are headless and rack-mounted. A failed switch that leaves sshd hung is a physical-recovery event. The wrapper auto-rollback transforms a brick into a transient regression. | Plain `nixos-rebuild switch` is what we were using when hlc-508 dropped off the network. The cost of the wrapper (~50 lines of shell) is trivial vs. the cost of pulling a Pi from a rack. |

## Stop and report

This plan ends after Phase 2 planning artifact updates. Run `/speckit-tasks` to
regenerate `tasks.md` against this reset plan; the existing tasks.md describes
the failed Phase A approach and should be replaced wholesale, not edited.
