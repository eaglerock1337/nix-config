<!--
SYNC IMPACT REPORT
==================
Version change: 1.3.1 → 1.3.2
Bump rationale: PATCH — clarify Principle IV's canary scope. Canary applies
to the *change set* being deployed, which MAY be a single module OR a
batched bundle (e.g. all module-creation work for a phase). When the change
set bundles multiple modules, smoke-test failure triggers a bisect via the
/speckit-debug skill (revert-and-incrementally-reintroduce on the canary
node) to isolate the breaking module before fleet roll. The canary +
smoke-test gate before any fleet roll still binds. No intent change to
Principle IV's safety guarantee; this clarifies cadence flexibility.

Modified principles:
  - IV. Safety-First Changes — added clarification that canary scope is the
    change set (single module or bundle), and that bundles require bisect-
    on-fail via /speckit-debug to preserve regression-isolation.

Modified sections:
  - Safety & Change Management — gate #4 references the bundle/bisect path.

Added principles: none
Removed sections: none

Templates checked:
  - .specify/templates/plan-template.md ✅ aligned (generic)
  - .specify/templates/spec-template.md ✅ aligned
  - .specify/templates/tasks-template.md ✅ aligned
  - .specify/templates/checklist-template.md ✅ aligned

Deferred TODOs: none

Prior version sync impacts (retained for history):
  1.3.0 → 1.3.1: PATCH — clarified Principle IV admits two canary paths
                 (automated and manual operator-driven).
  1.2.0 → 1.3.0: MINOR — added Principle VIII (Human-AI Collaboration
                 Protocol).
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

Every config change MUST be validated before applying. Changes to boot config,
hardware modules (power/thermal), or kernel parameters MUST additionally be
tested with `nixos-rebuild build-vm` when feasible.

**Canary requirement (cluster-transition phase, until prior art is fully
reintegrated)**: Any change that touches a cluster host's runtime state MUST
be deployed first to a single canary node, validated by a post-deploy smoke
test (reachability + interactive-PTY ssh + sudo round-trip), and only then
rolled to remaining nodes. SD-card reflash, local on-node `nixos-rebuild
switch`, and remote `nixos-rebuild switch --target-host` are all valid update
paths; the smoke-test gate applies to all three.

Two operator paths satisfy this requirement; either is acceptable so long as
the canary + smoke-test gate is honored before any fleet roll:

1. **Automated canary** — a single command performs switch + smoke-test +
   auto-rollback on smoke-test failure (e.g. a `make canary` target). When
   available, this is the preferred path.
2. **Manual canary** — operator runs `make update-node HOST=<canary>`, then
   `make smoke-test HOST=<canary>`, then on smoke-test failure runs `make
   rollback HOST=<canary>` explicitly. Only after smoke-test green does the
   operator proceed to remaining nodes.

The manual path MUST NOT be used to bypass smoke-test failures: a red
smoke-test always blocks the fleet roll until either the change is rolled
back or the failure is diagnosed and the smoke-test passes on a follow-up
deploy.

**Canary scope (single module vs bundle)**: The canary applies to the
*change set* being deployed. The change set MAY be a single module OR a
batched bundle (e.g. all module-creation work for an entire user-story
phase, deployed via `/speckit-implement` then a single `make update-node`).
Bundling is permitted because the canary + smoke-test gate still gates the
fleet roll. When the change set is a bundle, smoke-test failure on the
canary node MUST trigger a regression-isolation pass via the `/speckit-debug`
skill (rollback → comment-out / git-revert new modules incrementally → re-
canary → smoke-test → bisect to the breaking module → fix → resume the
bundle). This preserves the post-mortem lesson that motivated W-001 — the
operator MUST end up knowing which module broke — while permitting the
batched-implementation cadence the operator chose for speed.

**Refinement-stage relaxation**: Once the cluster is fully automated and the
prior-art bug surface is closed, the canary requirement MAY be replaced by
equivalent automation (CI gates, declarative rollout policy in ArgoCD or
similar). Until that automation exists, the canary + smoke-test gate is
mandatory in one of the two forms above.

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

### VII. Standardized Build & Test Workflow

All build and test operations MUST use Makefile targets as the canonical
interface. Direct CLI invocation of `nix build`, `nixos-rebuild`, or
`smoke-test.sh` is permitted during interactive triage; scripts, agents, and
any automated workflow MUST invoke Makefile targets to ensure a consistent,
documented interface.

**Host capability awareness**: Available commands differ by host. Commands MUST
be selected based on the executing host:

| Host | Role | Available | Not available |
|------|------|-----------|---------------|
| `gibson` | build host (x86_64) | `nix`, `nix build`, Makefile targets | `nixos-rebuild` (NixOS not yet installed — future project) |
| `silicon` | laptop (x86_64 NixOS) | `nix`, `nixos-rebuild`, Makefile targets | — |
| cluster nodes | aarch64 NixOS | `nix`, `nixos-rebuild` | Makefile (not cloned) |

When executing on `gibson`, use `nix build
.#nixosConfigurations.<host>.config.system.build.toplevel` for build
validation in place of `sudo nixos-rebuild dry-run`. Makefile targets already
abstract this distinction and MUST be preferred for any scripted or
agent-driven invocation.

This principle MUST be revisited when gibson receives NixOS system management
(tracked as a separate project outside the current feature scope).

### VIII. Human-AI Collaboration Protocol (NON-NEGOTIABLE)

This repo has exactly one stakeholder: the operator/SRE who owns and uses
the systems. There are no non-technical stakeholders, no product owners, and
no compliance reviewers. Therefore:

**Single-stakeholder model**: AI agents MUST NOT generate boilerplate framed
for non-technical audiences (executive summaries, simplified-for-stakeholders
explanations, "translation" docs). Output is for the operator. Use precise
technical vocabulary; assume Linux/SRE fluency.

**Debug-session conduct**: When the operator reports system state, command
output, log lines, or observed behavior, that data is treated as authoritative
input. Agents MUST NOT silently rewrite the working theory on the assumption
the operator misread, mistyped, or misremembered. If the data does not match
the agent's mental model, the correct response is one of:

1. State the conflict explicitly ("your output shows X but I expected Y
   because Z — can you confirm the command, host, or timing?");
2. Ask for an additional concrete data point that would disambiguate;
3. Re-examine the agent's own assumptions before challenging the operator's.

Operators make mistakes — that is allowed as a hypothesis, but it MUST be
raised as a question, never adopted as a silent premise. "Maybe you ran it
on the wrong host?" is fine. Quietly assuming so and pivoting the
investigation is a violation.

**Epistemic honesty**: Agents are expected to be capable but not omniscient.
When confidence is partial, that MUST be surfaced — "I'm fairly sure but not
certain", "I haven't verified this on aarch64", "this matches the docs but
I haven't tested the edge case" — rather than presented as fact. Hallucinated
certainty is the failure mode this principle exists to prevent. When in
doubt, prefer caution: ask, verify, or read the code before acting.

**Why**: A debug session on 2026-04-27 went off-rails because the working
theory drifted to "the operator's report is wrong" without that hypothesis
being explicitly raised. Branch state was corrupted; rebase recovery is
pending. This principle codifies the conduct that would have prevented it.

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

All changes follow this gate sequence. **Use Makefile targets** — they encode
host-correct commands and are the documented interface (Principle VII):

1. `make dry-run HOST=<host>` — verify closure diff (runs `nix build` on
   gibson; `nixos-rebuild dry-run` where available)
2. `make build HOST=<host>` — full toplevel build; catches evaluation-passed-
   but-build-fails errors that dry-run misses
3. `make build-vm HOST=<host>` — required for boot/kernel/hardware changes
   when feasible
4. **Canary on a single node** (scope = the change set, single module or
   batched bundle) — one of:
   - **Automated**: `make canary HOST=<host> IP=<ip>` (switch + smoke-test
     + auto-rollback on smoke-test fail) — preferred when target exists.
   - **Manual**: `make update-node HOST=<host>` then `make smoke-test
     HOST=<host>`; on smoke-test fail run `make rollback HOST=<host>`
     explicitly. On bundle smoke-test fail, follow `/speckit-debug` skill
     to bisect the bundle on the canary node before resuming. Both paths
     satisfy Principle IV.
5. **`make smoke-test HOST=<host>`** — reachability + interactive-PTY ssh
   + sudo round-trip (already executed inside gate #4 in either path; listed
   separately because gates #6 below run it again per node)
6. Roll to remaining work-set nodes serially; smoke-test after each
7. Tag commit at each phase exit gate for `git bisect` recovery

Boot config and hardware module edits require extra scrutiny before apply.
Rollback via NixOS boot menu generations is always available, but the goal
is never to need it.

For the decommissioned-set (hlc-402–404), gates 4 onward MUST NOT execute.
Only `make dry-run` (or equivalent `nix build` on gibson) is permitted.

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

**Version**: 1.3.2 | **Ratified**: 2026-04-25 | **Last Amended**: 2026-04-29
