# Implementation Plan: NixOS RPi Cluster Foundation (v2)

**Branch**: `001-nixos-rpi-cluster` | **Date**: 2026-04-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-nixos-rpi-cluster/spec.md`

## Summary

Bring 9 Raspberry Pis (`hlc-401` Pi 4 + `hlc-501..508` Pi 5) onto NixOS 25.11 using the actively-maintained `nvmd/nixos-raspberrypi` fork in place of the archived `nix-community/raspberry-pi-nix` currently on `main`. Each provisioned node ends with `/boot` on SD, `/` on a 2-disk USB-3 mdadm RAID1 mirror, and (Pi 5 only) `/srv/ssd` on a 1 TB NVMe. The repo carries evaluable host configurations for all 12 cluster nodes — the deferred Pi 4 control-plane peers (`hlc-402..404`) dry-run only, with no SD flash or remote switch. Operator UX (HLC MOTD, Bob Ross-themed PS1 in two forms, sysadmin toolbox shared with `silicon`, modular home-manager) and k3s OS-level prerequisites (k3s, k9s, `k` alias, kernel/sysctl) are in scope; cluster bootstrap and workload deployment are not. The plan respects the existing W-001..W-003 ledger entries: shared modules are reintroduced per node via canary deploys, not big-bang.

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable, plus `nixos-unstable` for selected packages)
**Primary Dependencies**:
- `nixpkgs` 25.11 (stable channel)
- `nixpkgs-unstable` (selected packages only, allowlist-controlled)
- `home-manager` release-25.11
- `nvmd/nixos-raspberrypi` (replaces `nix-community/raspberry-pi-nix`); branch and revision pinned by Phase 0 research
- `nixos-hardware` (Pi 4 / Pi 5 hardware modules)
- `nixos-anywhere` (one-shot remote install runner)
- `disko` (declarative disk layout — already a flake input)
- `sops-nix` (already a flake input; usage deferred per W-002)

**Storage**:
- SD card: `/boot` partition only after provisioning; full live recovery environment when USB array is absent (FR-011)
- USB RAID1 (mdadm, 2× 64 GB USB-3): `/` and `/srv/usb`
- NVMe (Corsair MP600 Micro 1 TB, Pi 5 only): `/srv/ssd`

**Testing**:
- `make dry-run HOST=<host>` — closure evaluation; gibson uses `nix build … --dry-run`, silicon uses `nixos-rebuild dry-run` (added Phase 2)
- `make build HOST=<host>` — full toplevel build (added Phase 2)
- `nixos-rebuild build-vm --flake .#<host>` — VM build for boot/kernel changes when feasible; Pi-targeted aarch64 builds may not VM-test; gate skipped for hardware modules with a documented note (no Makefile target)
- `make update-node HOST=<host>` — single-node `nixos-rebuild switch --target-host` (added Phase 6); operator manually canaries by running on one node, then `make smoke-test` to verify, then proceeding
- `make smoke-test HOST=<host>` — ping + non-PTY ssh + PTY ssh + `sudo -n true` (added Phase 2)
- `make rollback HOST=<host>` — single-node `nixos-rebuild --rollback --target-host` (added Phase 6)
- Automated canary (a single command that switches + smoke-tests + auto-rollbacks) is **out of scope for this spec**; the manual operator procedure above satisfies Constitution IV's canary requirement
- Acceptance via the operator runbook in `quickstart.md`

**Target Platform**: aarch64-linux NixOS 25.11 on RPi 4 (bcm2711) and RPi 5 (bcm2712); cross-compiled / cross-built on `gibson` (x86_64).
**Project Type**: NixOS flake-based system configuration repository.
**Performance Goals**: SD baseline boot to SSH-reachable < 5 min from power-on (SC-001 sub-bound); `nixos-anywhere` provisioning of one node < 30 min wall-clock (SC-001); rolling re-provisions sequential, no quorum constraint (cluster bootstrap out of scope).
**Constraints**:
- Provisioning idempotency: re-running provision on an already-installed node must not corrupt the array (FR-013).
- Boot recovery: removing both USB drives must drop the Pi into the SD live environment with `mdadm` available, no operator intervention beyond power cycle (FR-011, SC-005).
- xterm-safety on remote PS1: no color escapes (FR-017 remote form).
- Constitution Principle VIII: operator-supplied data is authoritative in debug sessions; no silent rewriting of working theory.

**Scale/Scope**: 13 NixOS hosts (`silicon` + 12 cluster nodes); 9 physically provisioned in this spec; ~15 modules (cluster, hardware, hosts, motd, shell, users, home, sd, disko); single Makefile is the canonical build/test interface.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* Constitution v1.3.0.

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | **Pass** | All host state expressed in NixOS modules; no imperative provisioning beyond the SD flash and the one-shot `nixos-anywhere` install (which itself runs declarative config). |
| II. Reproducibility via Flakes | **Pass** | All inputs locked in `flake.lock`. Upstream swap to `nvmd/nixos-raspberrypi` will pin a specific revision (chosen in Phase 0). |
| III. Modular Design | **Pass with active deferral** | Phase A inline-host workaround W-001 still open. New work done in this spec respects the W-001 exit plan: shared modules reintroduced one at a time via canary. No new monolithic module created. |
| IV. Safety-First Changes | **Pass** | Every cluster-touching change runs through `make dry-run` → `make build` → `make update-node` (single host first) → `make smoke-test` → on failure `make rollback`. Automated single-command canary (switch + smoke-test + auto-rollback) is the subject of a follow-on spec; within this spec the operator manually canaries by running `make update-node` on one node, verifying with `make smoke-test`, and only then continuing to the next node. NixOS boot-generation rollback is always available. |
| V. Pragmatic Phasing | **Pass** | W-002 (passwordless wheel) and W-003 (`PasswordAuthentication = true`) ledger entries cover the known deviations; both have target phases (W-002: future secrets-mgmt feature spec; W-003: Phase 5 SSH-hardening sub-step). No new workarounds introduced by this plan. |
| VI. Minimal & Explicit Footprint | **Pass** | Toolbox module package list is alphabetical with inline rationale comments per package (FR-015). No speculative modules; ecto-1 is structural readiness only, not stub artifacts. Unfree allowlist unchanged. |
| VII. Standardized Build & Test Workflow | **Pass** | Existing Makefile already exposes `dry-run`, `build`, `smoke-test`, `canary`, `rollback`, `build-image`, `flash-image`, `update-node`. Plan extends with the provisioning workflow target (`provision`) and updates `build-image` to honor the `--rebuild` story (FR-004). All scripted/agent invocations route through Makefile per Principle VII. |
| VIII. Human-AI Collaboration Protocol | **Applies to working method** | Plan acknowledges: any apparent disagreement with operator-reported state is raised, not silently routed around. The PS1 mountain-glyph presentation question is one such case — an explicit emoji-presentation strategy is required (Phase 0 research) rather than assumed. |

**Gate result**: Pass. No constitution violations require Complexity Tracking justification at this time.

## Project Structure

### Documentation (this feature)

```text
specs/001-nixos-rpi-cluster/
├── plan.md                  # This file (/speckit-plan command output)
├── spec.md                  # /speckit-specify + /speckit-clarify output
├── post-mortem-26-04-29.md  # Operator-authored context driving this rewrite
├── remote-ps1.txt           # Operator-supplied remote PS1 sample
├── research.md              # Phase 0 output (rewritten this cycle)
├── data-model.md            # Phase 1 output (rewritten this cycle)
├── quickstart.md            # Phase 1 output (rewritten this cycle)
├── contracts/               # Phase 1 output (rewritten this cycle)
└── tasks.md                 # Phase 2 output (/speckit-tasks; not produced here)
```

### Source code (repository root)

The target tree on completion of this spec. Existing paths are preserved where they already match; planned additions / refactors are noted inline.

```text
flake.nix                       # SWAP raspberry-pi-nix → nvmd/nixos-raspberrypi input;
                                # update mkHlcNode to use the new module names.
flake.lock                      # Re-locked after upstream swap.
Makefile                        # Add `provision HOST=... IP=...` target wrapping nixos-anywhere.
                                # Update `build-image` to honor a rebuild flag (FR-004).
WORKAROUNDS.md                  # Append entries for any new deviations (none expected;
                                # spec scope deliberately stays inside W-001..W-003).
README.md                       # Updated quick-reference (kept in sync with quickstart.md).

hosts/
├── silicon/                    # Existing; refactored only to share toolbox + home-manager
│   ├── configuration.nix       # base modules.
│   └── hardware-configuration.nix
├── hlc-401/                    # Pi 4 control-plane bootstrap (in scope).
│   └── configuration.nix
├── hlc-402..404/               # Pi 4 deferred set; configs evaluable, NEVER flashed.
│   └── configuration.nix       # (3 directories — hlc-402, hlc-403, hlc-404.)
└── hlc-501..508/               # Pi 5 worker class (8 directories; all in scope).
    └── configuration.nix

modules/
├── cluster/
│   ├── common.nix              # NEW: generic-cluster module (shared by HLC and any
│   │                           # future cluster like ecto-1). Includes the toolbox
│   │                           # import, k3s OS-level prereqs, base sshd posture.
│   └── hlc/                    # Existing dir; HLC-specific (operator user, MOTD,
│       ├── hosts.nix           # network, hostname conventions, marks.dev FQDNs).
│       └── ...                 # (existing modules adjusted to consume the new
│                               # generic cluster/common.nix where they overlap.)
├── hardware/
│   ├── rpi4.nix                # Existing; aligned with nvmd module names.
│   ├── rpi5.nix                # Existing; aligned with nvmd module names.
│   └── x1-carbon.nix           # Existing; unchanged.
├── hosts/                      # Existing; minor cleanup to remove silicon-only
│   ├── common.nix              # imports from cluster/common.nix.
│   ├── desktop-ui.nix
│   ├── gaming.nix
│   └── grub.nix
├── motd/
│   └── default.nix             # PARAMETERIZED: takes a banner module argument so future
│                               # clusters can override; HLC banner matches the post-mortem
│                               # exactly (FR-018).
├── shell/
│   ├── common.nix              # bash baseline (no PS1 setting) shared with silicon.
│   ├── prompt.nix              # REWRITE: implements local + remote PS1 forms per FR-017
│   │                           # with mountain-glyph presentation strategy from research.md.
│   └── utilities.nix           # toolbox; alphabetical packages with per-package comments
│                               # (FR-015). Imported on every NixOS host.
├── users/
│   └── operator.nix            # Existing; bob (cluster) + eaglerock (workstation) factored
│                               # so each is parameterizable; W-002/W-003 sites annotated.
├── home/
│   ├── base.nix                # Cross-cutting home-manager defaults shared between
│   │                           # bob and eaglerock (e.g. neovim baseline, git config).
│   ├── server.nix              # NEW: server-only home-manager (no GUI assumptions).
│   ├── workstation.nix         # NEW: workstation-only (i3/polybar/etc.) — silicon imports
│   │                           # this; cluster nodes do not.
│   ├── colors.nix              # Existing.
│   ├── dev.nix                 # Existing.
│   ├── i3.nix                  # Existing; pulled in by workstation.nix only.
│   ├── polybar.nix             # Existing; same.
│   ├── ui.nix                  # Existing.
│   └── vscode.nix              # Existing.
├── sd/                         # NEW: SD bootstrap configuration (FR-002, FR-003, FR-004).
│   ├── bootstrap.nix           # Barebones config: bob user + authorized key + network +
│   │                           # recovery utilities. NO per-host service modules.
│   └── recovery-utils.nix      # mdadm, parted, lsblk, basic editor, git, curl.
└── k8s/                        # NEW: k3s OS-level prereqs (FR-021, FR-022).
    └── prereqs.nix             # Packages, kernel modules, sysctls; service unit
                                # enabled-but-stopped per User Story 5 AS#2.

disko/                          # NEW: declarative disk layouts (FR-010..FR-014).
├── rpi4.nix                    # USB RAID1 root + /srv/usb; no NVMe.
└── rpi5.nix                    # USB RAID1 root + /srv/usb + NVMe at /srv/ssd.

home/                           # Existing per-user home-manager entry points (kept).
├── eaglerock.nix
└── bob.nix                     # NEW: imports server.nix + base.nix.

docs/
                                # (No cluster-ips.txt — IPs are derived from hostnames
                                # per the convention `hlc-VNN` → `10.23.50.<octet>`,
                                # documented in contracts/makefile-targets.md.)
├── syshelp-reference.md        # Existing toolbox markdown reference.
└── provisioning-runbook.md     # NEW: human-facing runbook mirroring quickstart.md.

secrets/                        # NEW (placeholder dir, no live secrets in this spec):
└── ssh-keys/                   # bob's authorized public keys, per-cluster (W-002 pre-sops).

assets/                         # Existing wallpapers/images; unchanged.
```

**Structure Decision**:
- **Three-scope module layering** (`cluster/common.nix` → `cluster/hlc/` → `hosts/<host>/`) plus device hardware (`hardware/rpi{4,5}.nix`) realizes spec FR-005..FR-008.
- **`modules/sd/` separated from `modules/cluster/`** so the bootstrap image cannot accidentally import per-host service config (FR-003).
- **`disko/` at the repo root** (not under `modules/`) because its schemas are consumed by `nixos-anywhere` orchestration as well as by per-host configurations; keeping them adjacent to the per-host configs makes the relationship visible.
- **Existing `silicon` configuration** is refactored only insofar as it needs to share `modules/shell/utilities.nix` and `modules/home/base.nix` with cluster nodes; workstation-only modules (i3, polybar, etc.) move under `modules/home/workstation.nix` so the split is explicit.
- **W-001 inline-host stance is preserved** for the duration of this spec's rollout. Shared modules are reintroduced one at a time, behind the canary gate, per the W-001 exit plan in `WORKAROUNDS.md`. This plan does not attempt the full module reintroduction in one go — that lesson is the entire reason for the post-mortem.

## Phasing notes (W-001 alignment)

The spec's user stories (P1..P5) align with these execution phases — written here so the plan reflects the W-001 reintroduction order. `/speckit-tasks` will expand each into discrete tasks.

0. **Baseline reset (no spec FR; post-mortem §"Restarting → Phase 1" mandate)** — strip the failed-attempt content from this branch back to `main`'s working state, while preserving the directory structure designed by this plan, the operator's infrastructure additions, and this spec's documents. Single commit; no canary needed (silicon dry-run + `hlc-501` SD image build + flash + smoke-test is the gate). See "Phase 0 — Baseline reset" below for the keep/delete/revert lists. Tag commit `phase0-baseline-reset`.
1. **Upstream swap (P1, FR-001)** — `raspberry-pi-nix` → `nvmd/nixos-raspberrypi`. Single PR; canary on `hlc-501`; smoke-test green before any other host changes.
2. **SD bootstrap rebuild (P1, FR-002..FR-004)** — `modules/sd/bootstrap.nix`; replaces today's image build path; validated by reflashing `hlc-501` + smoke-test.
3. **Per-host scaffolding (P2, FR-005..FR-009)** — verify all 12 hosts dry-run from a clean checkout; tighten `mkHlcNode`; introduce `modules/cluster/common.nix` skeleton.
4. **Disko + nixos-anywhere (P3, FR-010..FR-014)** — `disko/rpi{4,5}.nix`; add `make provision HOST=<host>` wrapping `nixos-anywhere`; provision `hlc-501` first, smoke-test, then sequential provisioning of remaining work-set with smoke-test after each.
5. **Operator UX (P4, FR-015..FR-020)** — toolbox, MOTD, PS1 (local + remote), home-manager modular split. Reintroduced module-by-module per W-001's exit plan. Add `make update-node HOST=<host>` and `make rollback HOST=<host>` here (first phase that does live-node config rollouts); each module is canaried manually: `make update-node` on `hlc-501`, `make smoke-test`, then proceed (or `make rollback` if needed).
6. **k3s prereqs (P5, FR-021..FR-023)** — `modules/k8s/prereqs.nix`; service enabled but stopped; cluster bootstrap explicitly out of scope.

## Phase 0 — Baseline reset

**Goal**: Bring the running code (the Nix configurations that actually build silicon and `hlc-501`) back to `main`'s working state, while keeping the documentation, planning, and tooling work that has been done above `main` so we don't redo it. The post-mortem's restart directive — "Restoration of existing code to baseline `main` branch before working again" — is satisfied by this reset.

**Principle**: Two buckets — "running code" (reverts to `main`) and "context" (kept). If a file gets compiled into a NixOS system or governs how Nix builds something, it is running code. If a file documents, plans, scaffolds spec-kit/Claude, or is operator-authored process work, it is context.

### Keep (spec-kit, Claude context, process work, build tooling)

These survive Phase 0 unchanged:

- `.specify/` — entire directory: constitution, templates, scripts, extensions, integrations, memory, workflows, `feature.json`, `init-options.json`, `integration.json`.
- `.claude/` — entire directory: agents, agent-memory.
- `CLAUDE.md`, `CLAUDE.original.md`.
- `specs/001-nixos-rpi-cluster/` — entire spec directory: `spec.md`, this `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `post-mortem-26-04-29.md`, `remote-ps1.txt`, `checklists/requirements.md`, `tasks.md` (the 119-task list, fresh from `/speckit-tasks` post-clarify).
- `WORKAROUNDS.md` — entries W-001..W-003 stay (already updated to reference Phase 5).
- `scripts/smoke-test.sh` — operator-authored helper; kept.
- `.gitignore` — kept; if `hlc-output.txt` / `lshw-output.txt` are not already ignored, they get added.
- `docs/syshelp-reference.md` — kept (documentation; revisited in Phase 5 when the toolbox module lands; retire then if no longer accurate).
- `docs/workflow.md` — kept (created during plan/analyze cycle; captures spec-kit workflow, debug patterns, planned hooks).
- `specs/001-nixos-rpi-cluster/tasks.md` — kept. Generated post-Phase-0 assumptions; the 119-task list is the source of truth from Phase 1 onward. Do **not** delete it during the reset.

### Revert to `main` (running code)

These are the files Nix actually evaluates to build silicon or `hlc-501`. Each is restored to `main`'s exact content:

- `flake.nix` — `main`'s version: `silicon` and `hlc-501` only as `nixosConfigurations`, `raspberry-pi-nix` as the upstream input, no `sops-nix` / `disko` / `operatorPubkey` / `mkHlcNode`. (The flake input additions are valuable but reach back into the failed attempt's wiring; they get re-introduced cleanly in Phase 1+ as needed.)
- `flake.lock` — re-locked after `flake.nix` revert.
- `hosts/silicon/configuration.nix`, `hosts/silicon/hardware-configuration.nix` — `main`'s content.
- `hosts/hlc-501/configuration.nix` — `main`'s content (the canonical Pi 5 baseline that boots).
- `home/eaglerock.nix` — `main`'s content.
- `modules/home/` — entire directory's content reverted to `main` (the home-manager modular split into base/server/workstation lands in Phase 5; not now).
- `modules/hosts/` — entire directory's content reverted to `main` (silicon system modules: `common.nix`, `desktop-ui.nix`, `gaming.nix`, `grub.nix`, `grub/` assets).
- `modules/hardware/x1-carbon.nix` — `main`'s content.
- `Makefile` — `main`'s content (`build-image`, `flash-image`, `silicon-dry`, `silicon-switch`, `update`, `help`). The branch-side build-out is **not** preserved up-front. This spec adds targets just-in-time per phase:
  - **Phase 2 Foundational**: `dry-run HOST=<host>`, `build HOST=<host>`, `smoke-test HOST=<host>`, `ip HOST=<host>`.
  - **Phase 3 US1**: `REBUILD=1` flag on existing `build-image` (FR-004).
  - **Phase 5 US3**: `provision HOST=<host>` wrapping `nixos-anywhere`.
  - **Phase 6 US4**: `update-node HOST=<host>` (per-node `nixos-rebuild switch --target-host` wrapper) and `rollback HOST=<host>` (per-node `nixos-rebuild --rollback --target-host` wrapper). Operator manually canaries by running `make update-node` on one host, running `make smoke-test` to verify, then proceeding to the next host (or `make rollback` if needed).

  **Out of scope for this spec** (future cluster-operations automation spec): automated `canary` (single command that switches + smoke-tests + auto-rollbacks); `update-cluster` (cluster-wide rolling deploy); cluster-wide iterations like `dry-run-all`, `smoke-test-all`; `build-image-rpi4` / `build-image-rpi5` convenience aliases; `encrypt-secret` (deferred per W-002 to a future secrets-management spec).

### Delete (failed-attempt-only files)

Files created during the prior incident with no counterpart on `main`:

- All Pi 4 host directories: `hosts/hlc-401/`, `hosts/hlc-402/`, `hosts/hlc-403/`, `hosts/hlc-404/`.
- All Pi 5 host directories except `hlc-501`: `hosts/hlc-502/`, `hlc-503/`, `hlc-504/`, `hlc-505/`, `hlc-506/`, `hlc-507/`, `hlc-508/`.
- `modules/cluster/` — entire directory.
- `modules/motd/` — entire directory.
- `modules/shell/` — entire directory.
- `modules/users/` — entire directory.
- `modules/hardware/rpi4.nix`, `modules/hardware/rpi5.nix`.
- Any branch-only file under `modules/home/` or `modules/hosts/` not present on `main` (e.g. if `modules/home/dev.nix` is branch-only).
- `hlc-output.txt`, `lshw-output.txt` — debug artifacts from the prior incident.

After deletion, no empty placeholder directories are left behind. Phase 1+ creates new directories as files land in them.

### Reset procedure

The reset is a single commit. Operator runs (or a `make reset-to-baseline CONFIRM=yes` target wraps):

```bash
# 1. Snapshot the pre-reset state for recovery.
git tag pre-reset-2026-04-29

# 2. Restore main's running code (including the minimal Makefile).
git checkout main -- \
    flake.nix flake.lock Makefile \
    hosts/silicon hosts/hlc-501 \
    home/eaglerock.nix \
    modules/home modules/hosts modules/hardware/x1-carbon.nix

# 3. Delete failed-attempt-only files.
git rm -r \
    hosts/hlc-401 hosts/hlc-402 hosts/hlc-403 hosts/hlc-404 \
    hosts/hlc-502 hosts/hlc-503 hosts/hlc-504 hosts/hlc-505 \
    hosts/hlc-506 hosts/hlc-507 hosts/hlc-508 \
    modules/cluster modules/motd modules/shell modules/users \
    modules/hardware/rpi4.nix modules/hardware/rpi5.nix
git rm -f hlc-output.txt lshw-output.txt

# 4. Add debug artifacts to .gitignore if not already.
#    (Manual edit; verify with: grep -E '(hlc|lshw)-output' .gitignore)

# 5. Commit.
git commit -m "Phase 0: baseline reset — running code to main, context kept"

# 6. Validate (see gate below). On green:
git tag phase0-baseline-reset
```

If a `make reset-to-baseline CONFIRM=yes` target is preferred, it MUST refuse without `CONFIRM=yes`, MUST `git tag pre-reset-<timestamp>` before any destructive op, and MUST run the validation gate before tagging `phase0-baseline-reset`. Operator decides whether to add the target now or do it by hand once.

### Validation gate (Phase 0 exit)

All four MUST pass before tagging `phase0-baseline-reset`:

1. `make silicon-dry` — silicon's NixOS config evaluates clean (target exists on `main`).
2. `make build-image HOST=hlc-501` — Pi 5 SD image builds. Still on `raspberry-pi-nix` here; nvmd swap is Phase 1. (No `build-image-rpi5` alias on `main`; the parameterized form is canonical.)
3. `make flash-image HOST=hlc-501 DEV=/dev/sdX` — image flashes.
4. Insert SD into `hlc-501`, power on. Verify reachability manually: `ping -c1 10.23.50.51 && ssh bob@10.23.50.51 true && ssh -t bob@10.23.50.51 true && ssh bob@10.23.50.51 sudo -n true` — all four succeed. (`make smoke-test` is added at the start of Phase 2 Foundational; until then, the manual ssh check is the gate.)

If any step fails, the reset is incomplete. Diagnose and re-run until green. Do **not** proceed to Phase 1 with a yellow gate — Constitution VIII applies (operator-observed state is authoritative, do not silently assume around it).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified.**

No new violations. The three open ledger entries (W-001 inline hosts; W-002 passwordless wheel; W-003 password auth) are pre-existing and have documented exit conditions. The Phase 0 reset *removes* state rather than adding deviations; the existing ledger entries become more accurate post-reset (the inline hosts they describe will not yet exist, and W-001's exit phase reference will be updated to match this plan's Phase 5).
