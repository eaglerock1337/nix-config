<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.0 → 1.1.0
Bump rationale: MINOR — two new principles added (V Pragmatic Phasing,
re-numbered Minimal & Explicit Footprint to VI), one new section
(Cluster Topology & Phasing), Principle III softened with deferral
clause, Principle IV strengthened with mandatory canary + smoke-test
during transition. No principle removed; no backward-incompatible
governance redefinition.

Modified principles:
  - III. Modular Design — added "deferrable during baseline/transition;
    non-negotiable in refinement" qualifier with WORKAROUNDS.md tracking
    requirement
  - IV. Safety-First Changes — strengthened: canary deploy +
    post-deploy smoke-test mandatory for any change touching a node
    that is not already validated in CI/build-vm; explicit until prior
    art is fully reintegrated

Added principles:
  - V. Pragmatic Phasing (NEW) — short-term workarounds permitted if
    logged in WORKAROUNDS.md with an exit condition

Renumbered:
  - V. Minimal & Explicit Footprint → VI. Minimal & Explicit Footprint

Added sections:
  - Cluster Topology & Phasing — defines work-set (hlc-401, hlc-501–508)
    vs decommissioned-set (hlc-402–404 Debian, untouched until parity),
    4-node etcd choice (acknowledged non-ideal, accepted)

Removed sections: none

Templates checked:
  - .specify/templates/plan-template.md ✅ aligned (Constitution Check
    section is generic; principle numbering update propagates only via
    plan files that name principles by number — Phase A1 plan.md uses
    names not numbers, no edit needed)
  - .specify/templates/spec-template.md ✅ aligned (FR/SC neutral)
  - .specify/templates/tasks-template.md ✅ aligned (no principle refs)
  - specs/001-nixos-rpi-cluster/plan.md ⚠ pending — Constitution Check
    table references principle numbers I–V; needs minor edit to add
    Principle V (Pragmatic Phasing) and renumber Minimal Footprint as
    VI in the table only, plus a row mentioning the Cluster Topology
    section's work-set rule
  - specs/001-nixos-rpi-cluster/tasks.md ⚠ pending — Phase 4 task list
    (T017–T028) addresses all 12 hosts; per new Cluster Topology
    section, hlc-402/403/404 are decommissioned-set and MUST NOT be
    flashed/booted until decommission day. Tasks need scoping to
    work-set (9 hosts: hlc-401, hlc-501–508) for the active rollout,
    with the 3 control-plane decommission-set hosts deferred to a new
    Phase B' (decommission + reflash) inserted between current Phases
    6 and 7 — or kept as flake-evaluating-only host configs that never
    get flashed in this cycle.
  - WORKAROUNDS.md ⚠ pending creation — required by Principle V

Deferred TODOs:
  - WORKAROUNDS.md ledger file does not yet exist; will be created at
    first workaround entry (the passwordless-sudo and
    PasswordAuthentication-default workarounds for Phase A1 are the
    likely first entries).
-->

# nix-config Constitution

## Core Principles

### I. Declarative Configuration (NON-NEGOTIABLE)

All system state MUST be expressed declaratively in Nix. Imperative changes
applied outside the config (e.g., `apt install`, manual edits to `/etc`) are
forbidden — they break reproducibility and will be lost on next rebuild.
Every host, user environment, and service MUST be derivable from source.

### II. Reproducibility via Flakes (NON-NEGOTIABLE)

All dependencies MUST be locked in `flake.lock`. Direct channel references
or unfenced `builtins.fetchX` calls that bypass the lock are prohibited.
Any system MUST be rebuildable from a clean checkout without manual steps.

### III. Modular Design

One concern per module file. Modules MUST be importable independently.
Cross-cutting state (colors, shared options) goes in dedicated shared modules
(e.g., `modules/home/colors.nix`). No monolithic catch-all config files.

**Phased deferral clause**: During baseline-establishment and prior-art
reintroduction (cluster transition phases A and B as defined in the active
feature plan), this principle MAY be temporarily relaxed — for example,
duplicating a small inline config across N host files instead of importing a
shared module — when doing so reduces blast radius for an unknown regression.
Any such deferral MUST:

1. Be logged in `WORKAROUNDS.md` with an explicit exit condition (typically
   "removed once Phase C reintroduces module X with canary validation");
2. Be removed at the refinement stage (Phase C onwards) without exception.

Once the cluster reaches refinement, this principle is non-negotiable.

### IV. Safety-First Changes (NON-NEGOTIABLE)

Every config change MUST be validated with `sudo nixos-rebuild dry-run --flake .#<host>`
before applying. Changes to boot config, hardware modules (power/thermal), or
kernel parameters MUST additionally be tested with `nixos-rebuild build-vm`
when feasible.

**Canary requirement (cluster-transition phase, until prior art is fully
reintegrated)**: Any change that touches a cluster host's runtime state MUST
be deployed first to a single canary node, validated by an automated
post-deploy smoke test (reachability + interactive-PTY ssh + sudo round-trip),
and only then rolled to remaining nodes. The canary deploy MUST auto-rollback
on smoke-test failure. SD-card reflash, local on-node `nixos-rebuild switch`,
and remote `nixos-rebuild switch --target-host` are all valid update paths;
the smoke-test gate applies to all three.

**Refinement-stage relaxation**: Once the cluster is fully automated and the
prior-art bug surface is closed, the canary requirement MAY be replaced by
equivalent automation (CI gates, declarative rollout policy in ArgoCD or
similar). Until that automation exists, canary is mandatory.

No skipping dry-run "just this once."

### V. Pragmatic Phasing

Short-term workarounds are permitted when they unblock a higher-priority
principle (typically Principle IV — keep nodes reachable and recoverable).
Examples in scope: passwordless `wheel` sudo during initial bring-up;
`PasswordAuthentication = true` deferred to a later hardening pass; inline
host configs deferring Principle III.

Each workaround MUST:

1. Have an entry in `WORKAROUNDS.md` (see Governance) with: short title, the
   principle or future state it deviates from, the exit condition (what must
   be true to remove it), and a target phase or feature spec where it ends.
2. Have a code-comment at the deviation site referencing the ledger entry.
3. Have a tracked task or phase plan that addresses the exit condition.

A workaround without all three is a violation of this principle, regardless
of its technical merit.

**Priority during refinement**: When the project enters the refinement stage,
addressing open workarounds drops in priority below ongoing spec refinement
itself — the spec is expected to evolve as the operator learns how systems
should behave, and re-prioritizing workaround removal mid-refinement risks
the very loop this principle exists to prevent. Workarounds MUST still be
removed before a stage is declared complete (e.g., before the cluster is
considered "production").

### VI. Minimal & Explicit Footprint

Packages MUST be alphabetically sorted in lists. Unfree packages MUST be on
the explicit allowlist — no new additions without documented justification and
discussion. YAGNI applies: no pre-emptive abstractions or speculative modules.
Start simple; add complexity only when the need is demonstrated.

## Cluster Topology & Phasing

The HLC cluster is in a phased migration. Two clusters coexist on the
`10.23.50.0/24` subnet during the transition; cutover is by DNS and
load-balancer changes (workloads are stateless — no data migration).

### Work-set (active NixOS development)

9 nodes are in scope for active NixOS bring-up, configuration, and remote
update during the transition:

- `hlc-401` — Pi4 control-plane bootstrap node (init server, `clusterInit = true`)
- `hlc-501` through `hlc-508` — 8× Pi5 worker nodes

These 9 nodes are flashed, booted, smoke-tested, canary-deployed against, and
iterated on. They form the new cluster.

### Decommissioned-set (untouchable until parity)

3 nodes remain on the **old Debian cluster** and host the live stateless
workloads (`marks.dev`, `hlc.marks.dev`, `mr-poopybutthole`, etc.):

- `hlc-402`, `hlc-403`, `hlc-404` — Pi4 control-plane on Debian

These nodes MUST NOT be flashed, rebooted, or have NixOS-side configuration
deployed to them until **all** of the following are true:

1. The work-set is at feature parity with the old cluster (k3s up, ingress,
   storage, all stateless workloads runnable on the new cluster).
2. DNS / load-balancer cutover has been completed and verified — old-cluster
   workloads are no longer receiving production traffic.
3. A scheduled decommission window exists for reflashing 402–404.

The 3 decommissioned-set nodes MAY have host configs present in `flake.nix`
(so `nixos-rebuild dry-run --flake .#hlc-402` evaluates) but MUST NOT have
SD images flashed or remote `nixos-rebuild switch` invoked against them. The
canonical state for these nodes during the transition is "Debian, untouched."

### Final state

After decommission of 402–404 and reflash to NixOS:

- 4 Pi4 server nodes (hlc-401–404) form the embedded etcd control plane.
- 4 nodes for embedded etcd is **not** the textbook ideal (3 or 5 is
  preferred for clean quorum) but is accepted by the project owner as
  acceptable for this hardware footprint. Quorum behavior on a 4-node etcd
  is documented and any operational impact is owned at runtime, not by spec.
- 8 Pi5 agent nodes (hlc-501–508) handle workloads and Longhorn storage.

## Safety & Change Management

All changes follow this gate sequence:

1. `dry-run` — verify closure diff looks correct
2. `build` — full toplevel build (`nix build
   .#nixosConfigurations.<host>.config.system.build.toplevel`); catches
   evaluation-passed-but-build-fails errors that `dry-run` misses
3. `build-vm` — required for boot/kernel/hardware changes when feasible
4. **Canary deploy** — switch on a single node; auto-rollback on smoke-test
   failure (Principle IV)
5. **Smoke test** — reachability + interactive-PTY ssh + sudo round-trip
6. Roll to remaining work-set nodes serially; smoke-test after each
7. Tag commit at each phase exit gate for `git bisect` recovery

Boot config and hardware module edits require extra scrutiny before apply.
Rollback via NixOS boot menu generations is always available, but the goal
is never to need it.

For the decommissioned-set (hlc-402–404), gate 4 onward MUST NOT execute.
Only `dry-run` is permitted, to confirm the host configs evaluate.

## Coding Standards

- **Indentation**: 2 spaces, no tabs
- **Comments**: explain *why*, not *what*; well-named identifiers carry the
  what. Workaround sites MUST comment-link to the relevant `WORKAROUNDS.md`
  entry (Principle V).
- **Colors**: use `modules/home/colors.nix` values — no inline hex outside
  that module
- **Stable vs unstable**: default to stable (25.11); pin to unstable only when
  a specific package version requires it, and document why
- **Package lists**: alphabetically sorted when practical
- **Unfree allowlist**: explicit opt-in per package, justified in commit message

## Governance

This constitution supersedes all other development practices in this repo.
Amendments require:

1. Update `constitution.md` with new/revised principles
2. Increment version per semantic versioning:
   - MAJOR: principle removal or backward-incompatible redefinition
   - MINOR: new principle or materially expanded guidance
   - PATCH: clarifications, wording, typos
3. Update `CLAUDE.md` if the amendment affects agent guidance
4. Dry-run and apply any config changes the amendment mandates
5. Commit with message: `docs: amend constitution to vX.Y.Z (<summary>)`

### WORKAROUNDS.md ledger (Principle V requirement)

`WORKAROUNDS.md` is a flat-file ledger at the repo root. Each entry has the
form:

```markdown
## W-NNN: <short title>
- **Site(s)**: <file:line or module path(s)>
- **Deviates from**: <Principle ID, or future-state target>
- **Reason**: <why the workaround was introduced>
- **Exit condition**: <what must be true to remove it>
- **Target phase / feature**: <e.g., "Phase 7f T098 SSH hardening" or "feature 002 secrets management">
- **Opened**: YYYY-MM-DD
- **Resolved**: YYYY-MM-DD (filled when removed; entry retained as record)
```

Workaround entries are append-only (never edit history; mark resolved
in-place). The ledger is reviewed at every phase-exit gate and at every
`/speckit-plan` cycle for a new feature.

All PRs and Claude-assisted changes MUST verify compliance with these
principles before declaring work complete. Pull requests that introduce
new workarounds MUST include the corresponding ledger entry in the same
commit (or earlier in the branch history).

**Version**: 1.1.0 | **Ratified**: 2026-04-25 | **Last Amended**: 2026-04-26
