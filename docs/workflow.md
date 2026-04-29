# Workflow — spec-kit, Claude resources, debugging patterns

**Last updated**: 2026-04-29
**Constitution**: v1.3.0
**Active feature**: `001-nixos-rpi-cluster`

This document captures how this repo uses spec-kit, which Claude resources are wired in (or planned), and the debugging patterns we converged on after the 2026-04-26 incident. It is documentation, not enforced policy — Constitution v1.3.0 is what binds. This doc explains *how* the constitution gets executed in practice.

## 1. spec-kit cycle

Each feature follows this sequence. Verification gates (in **bold**) are mandatory between steps; skipping them is the failure mode that produced the post-mortem.

```text
specify
  ↓
clarify (loop until no high-impact unknowns; max 5 questions per session)
  ↓
plan (research.md + data-model.md + contracts/ + quickstart.md)
  ↓
**analyze**  ← cross-artifact consistency gate; non-negotiable
  ↓
tasks
  ↓
checklist (per-phase review checklists, optional but recommended)
  ↓
implement — ONE phase at a time
  ↓
**canary** on a designated node (typically hlc-501)
  ↓
**smoke-test** green
  ↓
git tag the phase exit
  ↓
loop to next phase OR back to clarify/plan if scope shifted
```

Concrete rules:

- **Always run `/speckit-analyze` between `plan` and `tasks`.** It catches the spec ↔ plan ↔ research drift that compounds into incidents.
- **Never `/speckit-implement` more than one phase per cycle.** Phase tags are bisect anchors; one phase per cycle keeps each anchor meaningful.
- **WORKAROUNDS.md is reviewed at every `/speckit-plan` cycle** (Constitution V mandate). New deviations require a ledger entry in the same commit.
- **`/speckit-taskstoissues` is optional for solo work.** Useful only when collaborating; for now, `tasks.md` + commit messages are the source of truth.

## 2. Debugging patterns — there is no `/debug` skill

spec-kit does not ship a `/debug` command. Reach for the right tool by failure mode:

| Symptom | Tool / response |
|---------|-----------------|
| Implementation step hits unexpected behavior; scope holds | Standard Claude tools (Bash, Read, Grep, agents) + Constitution VIII (raise the conflict, never silently rewrite the working theory) |
| Mid-implementation ambiguity surfaces in spec | `/speckit-clarify` — appends to existing Clarifications log |
| Spec ↔ plan ↔ tasks drift detected | `/speckit-analyze` — designed exactly for this |
| Scope itself shifts | Re-run `/speckit-specify` (overwrites spec.md), then `/speckit-plan`, then `/speckit-tasks` to regenerate downstream |
| Branch state corrupted (post-mortem scenario) | `git` directly — revert/reset to last phase tag; spec-kit doesn't own git recovery |
| Unexplained failure mid-rollout | Constitution VIII: stop, raise the conflict explicitly, ask for the data point that disambiguates. Do not pivot the working theory silently. |

When in doubt, the constitution wins. Principle VIII (Human-AI Collaboration Protocol) is the explicit guard against the post-mortem failure mode.

## 3. Claude resources — current and planned

### Active

- **`nixy-boi` agent** (`.claude/agents/nixy-boi.md`, memory at `.claude/agent-memory/nixy-boi/MEMORY.md`) — NixOS expert; covers most NixOS work in this repo.
- **`update-config` skill** — used to wire hooks/permissions in `.claude/settings.json` when needed.
- **Project memory** at `~/.claude/projects/-Users-petermarks-src-nix-config/memory/` — current entries: `feedback_iterative_planning.md` (one-layer-at-a-time), `project_hlc_ip_convention.md` (IP derivation rule).

### Planned (high ROI; wire when convenient)

- **PreToolUse hook — decommissioned-set guard**: block any `Bash` tool call matching `(nixos-rebuild|make (canary|update-node|provision|flash-image|smoke-test))` against `hlc-40[234]` or against `bob@10\.23\.50\.4[234]`. Constitution §"Cluster Topology" forbids touching the decom-set; this hook makes it enforced rather than aspirational.
- **PreToolUse hook — `dd` safety**: block `dd .* of=/dev/(sda|nvme0n1)` and similar patterns that would clobber a system disk during SD flash.
- **PreToolUse hook — destructive git**: require operator confirmation for `git push --force`, `git reset --hard`, `git clean -fd`. Lower priority since Claude Code already prompts for these by default in normal permission mode.
- **SessionStart hook — status block**: echo `git describe --tags --match 'phase*'`, current branch, open WORKAROUNDS count + IDs, and last `make smoke-test-all` result if cached. Counters drift in long-running sessions.

### Considered but not adopted

- Custom `/phase-gate` or `/cluster-status` slash commands: the Makefile already exposes `dry-run-all`, `smoke-test-all`, `silicon-dry`, etc. Duplicating that surface as slash commands gains nothing.
- Additional subagents beyond `nixy-boi`: not yet justified by repeated need. Re-evaluate if a specific task pattern recurs (e.g., parallel multi-node smoke-test during rolling updates).

### `fewer-permission-prompts` skill

After several canary cycles produce a stable set of routine read-only Bash invocations (`git status`, `make dry-run`, `nix build`, `make ip`, `ssh -o BatchMode=yes ... true`), run the `fewer-permission-prompts` skill to allowlist them. Avoid running it before patterns stabilize; premature allowlists are debt.

## 4. Per-feature checklist

When starting a new feature on this repo:

1. **Constitution review** — re-read `.specify/memory/constitution.md`. If a principle needs to change, that's a separate constitution amendment commit, not a quiet drift inside the feature.
2. **Workarounds review** — read `WORKAROUNDS.md`. Does the new feature interact with an open workaround? If so, does it close it, extend it, or leave it untouched?
3. **`/speckit-specify`** — capture WHAT and WHY. Stay out of HOW.
4. **`/speckit-clarify`** — loop until no high-impact unknowns remain.
5. **`/speckit-plan`** — capture HOW: research, data model, contracts, quickstart.
6. **`/speckit-analyze`** — gate before tasks.
7. **`/speckit-tasks`** — generate per-phase tasks.
8. **`/speckit-checklist`** — optional per-phase review checklist.
9. **`/speckit-implement`** — one phase at a time; tag each phase exit.

## 5. Per-implementation checklist (per phase)

For each phase within a feature:

1. Read the phase's section in `quickstart.md`.
2. Run the phase's pre-conditions (typically `dry-run` + `build` for affected hosts).
3. Implement the phase's task list.
4. **Canary on the designated node** (`hlc-501` for most cluster work).
5. **Smoke-test green** (`make smoke-test HOST=<host>`).
6. Roll to remaining work-set nodes serially (`make update-node` per node, smoke-test after each).
7. Tag the commit (`git tag phase<N>-<short-name>`).
8. If anything surprises you, **stop**. Apply Constitution VIII. Do not push past unexplained state.

## 6. Where this document lives in the workflow

This doc is read by humans and agents at:

- The start of any new feature cycle (alongside the constitution).
- The start of any debugging session (the table in §2 is the entry point).
- When wiring or revisiting Claude hooks/skills (§3).

If the workflow itself changes, update this doc in the same commit as the change. If a section grows beyond the page, split it out (e.g., `docs/hooks.md`); but keep the cycle map and debug table here for fast operator reference.
