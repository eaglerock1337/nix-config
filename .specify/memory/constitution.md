<!--
SYNC IMPACT REPORT
==================
Version change: [unfilled template] → 1.0.0
Modified principles: N/A (initial ratification)
Added sections:
  - Core Principles (I–V)
  - Safety & Change Management
  - Coding Standards
  - Governance
Removed sections: N/A
Templates checked:
  - .specify/templates/plan-template.md ✅ aligned (Constitution Check gate present)
  - .specify/templates/spec-template.md ✅ aligned
  - .specify/templates/tasks-template.md ✅ aligned
Deferred TODOs: none
-->

# nix-config Constitution

## Core Principles

### I. Declarative Configuration (NON-NEGOTIABLE)

All system state MUST be expressed declaratively in Nix. Imperative changes
applied outside the config (e.g., `apt install`, manual edits to `/etc`) are
forbidden — they break reproducibility and will be lost on next rebuild.
Every host, user environment, and service MUST be derivable from source.

### II. Reproducibility via Flakes

All dependencies MUST be locked in `flake.lock`. Direct channel references
or unfenced `builtins.fetchX` calls that bypass the lock are prohibited.
Any system MUST be rebuildable from a clean checkout without manual steps.

### III. Modular Design

One concern per module file. Modules MUST be importable independently.
Cross-cutting state (colors, shared options) goes in dedicated shared modules
(e.g., `modules/home/colors.nix`). No monolithic catch-all config files.

### IV. Safety-First Changes

Every config change MUST be validated with `sudo nixos-rebuild dry-run --flake .#<host>`
before applying. Changes to boot config, hardware modules (power/thermal), or
kernel parameters MUST additionally be tested with `nixos-rebuild build-vm`
when feasible. No skipping dry-run "just this once."

### V. Minimal & Explicit Footprint

Packages MUST be alphabetically sorted in lists. Unfree packages MUST be on
the explicit allowlist — no new additions without documented justification and
discussion. YAGNI applies: no pre-emptive abstractions or speculative modules.
Start simple; add complexity only when the need is demonstrated.

## Safety & Change Management

All changes follow this gate sequence:

1. `dry-run` — verify closure diff looks correct
2. `build` (optional) — build without switching, confirm no build errors
3. `build-vm` — required for boot/kernel/hardware changes
4. `switch` — apply to live system

Boot config and hardware module edits require extra scrutiny before apply.
Rollback via NixOS boot menu generations is always available, but the goal
is never to need it.

## Coding Standards

- **Indentation**: 2 spaces, no tabs
- **Comments**: explain *why*, not *what*; well-named identifiers carry the what
- **Colors**: use `modules/home/colors.nix` values — no inline hex outside that module
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

All PRs and Claude-assisted changes MUST verify compliance with these
principles before declaring work complete.

**Version**: 1.0.0 | **Ratified**: 2026-04-25 | **Last Amended**: 2026-04-25
