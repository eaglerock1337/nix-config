---
name: "speckit-debug"
description: "Bisect a failed bundle canary to isolate the breaking module. Drives rollback, incremental module reintroduction, smoke-test gating, and root-cause reporting. Trigger when /speckit-implement bundles a phase, the canary deploy on hlc-501 (or other designated canary node) hits a red `make smoke-test`, and the operator needs to identify which module in the bundle caused the regression. Implements Constitution v1.3.2 §IV bisect-on-fail flow that backs the phase-bundle canary path. Also use when the user says \"debug the canary\", \"bisect the bundle\", \"which module broke\", or invokes /speckit-debug."
argument-hint: "Optional: HOST override (default: hlc-501) and/or starting bundle commit range (default: range from prior phase tag to HEAD)"
compatibility: "Requires spec-kit project structure with .specify/ directory, a tasks.md describing a bundle canary, and a working `make update-node` / `make smoke-test` / `make rollback` Makefile target set"
metadata:
  author: "peter.marks@betterment.com"
  source: "specs/001-nixos-rpi-cluster — phase-bundle cadence + Constitution v1.3.2"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. If empty, default the canary HOST to `hlc-501` and bisect range to `<prior phase tag>..HEAD`.

## Context

This skill is the recovery path for the **phase-bundle canary** cadence introduced in Constitution v1.3.2 §IV. The bundle replaces the prior per-module canary cadence: `/speckit-implement` runs all module-creation + wiring tasks for a phase, then a single `make update-node HOST=<canary>` deploys the bundle, gated by `make smoke-test HOST=<canary>`. When that smoke-test fails, this skill drives the regression isolation that the per-module cadence used to provide implicitly.

The post-mortem lesson (operator must end up knowing which module broke — see W-001 in `WORKAROUNDS.md`) is preserved by this bisect flow, NOT by the canary cadence itself.

## Pre-Execution Checks

1. **Verify the failure**:
   - Run `make smoke-test HOST=<canary>`. If it succeeds, abort — there is nothing to debug. Tell the operator to re-check the assumption that the canary is red.
   - If it fails, capture which step failed (ping / non-PTY ssh / PTY ssh / `sudo -n true`) and any error output. This is the regression signature.

2. **Verify rollback is possible**:
   - Run `ssh bob@<canary> 'sudo nixos-rebuild list-generations'`. The canary MUST have at least one prior generation (the pre-bundle baseline). If only one generation exists, the canary substrate is corrupt — escalate to the operator; do not proceed.

3. **Identify the bundle**:
   - Determine the bundle commit range. Default: prior phase tag (e.g. `phase4-disko-provisioning`) to `HEAD`. Confirm with operator if ambiguous.
   - List the new module-creation commits in that range: `git log --oneline <prior-tag>..HEAD`.
   - List the module imports added to `modules/cluster/common.nix` and `modules/cluster/hlc/default.nix` in the bundle: `git diff <prior-tag>..HEAD -- modules/cluster/common.nix modules/cluster/hlc/default.nix`. These are the bisect candidates.

## Execution Steps

### 1. Roll back the canary

```bash
make rollback HOST=<canary>
make smoke-test HOST=<canary>
```

The post-rollback smoke-test MUST be green. If it is not, the failure pre-existed the bundle — escalate to the operator. Do not proceed with bisect.

### 2. Identify the bisect candidates

Read `modules/cluster/common.nix` and `modules/cluster/hlc/default.nix`. Parse the `imports` list in each. Compare against the prior-tag baseline (`git show <prior-tag>:modules/cluster/common.nix`) to identify module imports ADDED in the bundle. These are the candidates.

Build a candidate list, ordered by suspicion (heuristic — present this list to the operator, they may reorder):

1. `modules/users/operator.nix` (high — touches authentication, can lock out `bob`)
2. `modules/shell/prompt.nix` (medium — affects login shell behavior; mountain-glyph rendering edge cases)
3. SSH hardening setting in `modules/cluster/common.nix` (medium — `PasswordAuthentication = false` + `KbdInteractiveAuthentication = false` can mask bad authorized_keys)
4. `modules/motd/default.nix` (low — login banner)
5. `modules/cluster/hlc/motd-banner.nix` (low — banner content)
6. `modules/shell/utilities.nix` (very low — package additions only)
7. `modules/shell/common.nix` (very low — bash baseline aliases)
8. Home-manager modules (low-medium — config writes can fail at activation time)

### 3. Bisect

Default strategy: **binary bisect** if candidate count > 4; **linear (most-suspicious-first)** if ≤ 4.

For each iteration:

1. Comment out the module imports under test in `modules/cluster/common.nix` and/or `modules/cluster/hlc/default.nix` (use `# DEBUG-BISECT:` comment marker so they are easy to find and restore).
2. Stage the change locally — DO NOT commit during bisect (commits during bisect pollute the bundle's commit history; the bisect operates on the working tree).
3. Run `make dry-run HOST=<canary>` first to catch evaluation errors before touching the node.
4. Run `make update-node HOST=<canary>`.
5. Run `make smoke-test HOST=<canary>`.
6. Interpret:
   - Smoke-test green → the commented-out modules contain the breaking change. Narrow to that subset.
   - Smoke-test red → the breaking change is in the still-active modules. Narrow to that subset.
7. Restore the comment markers and repeat until exactly one module is identified.

### 4. Diagnose the breaking module

Once isolated, read the module's source. Common failure modes to check:

- **operator.nix**: `bob`'s authorized key string (typo, encoding, missing newline); `wheel` membership not granted; `sudo -n` failing because `security.sudo.wheelNeedsPassword` was not set false.
- **prompt.nix**: PS1 syntax error (unescaped `\`, mismatched `\[ \]`); mountain glyph not rendering and breaking line wrap; remote form pulling color escapes.
- **SSH hardening**: `bob`'s authorized_keys not actually deployed (key-only enforcement bricks login); a stray service depending on password auth.
- **MOTD**: option type mismatch (`cluster.motd.banner` declared as `lines` but set as `str`, etc.).
- **home-manager**: file collision with existing dotfile; `home.activation` script failure; module evaluating differently for `bob` vs `eaglerock`.

Report findings to the operator with:
- Identified module
- Specific line(s) suspected
- Proposed fix
- Whether the fix is in the module itself or in the wiring (option set in wrong scope, etc.)

### 5. Fix and resume

After the operator approves the fix:

1. Edit the module to apply the fix.
2. Restore all `# DEBUG-BISECT:` comment markers so the full bundle is back in play.
3. Run `make dry-run HOST=<canary>` → green.
4. Run `make update-node HOST=<canary>` → success.
5. Run `make smoke-test HOST=<canary>` → green.
6. Hand control back to `/speckit-implement` (or operator) to resume the fleet roll.
7. Commit the fix as a follow-up commit on top of the bundle (do NOT amend bundle commits — preserve the bundle history for `git bisect` archaeology).

## Escalation

Escalate to the operator (do NOT proceed silently) when:

- Rollback smoke-test is also red (substrate-level issue, not a bundle issue).
- More than one module appears to be implicated (cross-module interaction; bisect logic above does not cover this).
- Bisect requires more than 6 iterations (suggests the failure mode isn't isolatable to a single module).
- The breaking change is in a wired option set (cluster scope) rather than a module file (refactoring may be needed before re-canary).

Constitution VIII applies: surface uncertainty, do not silently rewrite the operator's working theory.

## Report Format

After bisect completes, return a structured report:

```markdown
## /speckit-debug Report

**Canary host**: <hostname>
**Bundle range**: <prior-tag>..HEAD (<n> commits, <m> modules in scope)
**Iterations**: <count>
**Breaking module**: `path/to/module.nix`
**Failure mode**: <one-line summary, e.g. "operator.nix authorized_keys missing trailing newline → sshd rejects bob's key">
**Proposed fix**: <one-paragraph fix description>
**Re-canary status**: green | pending operator review

### Bisect log
- Iter 1: commented out [<module list>] → smoke-test <green|red>
- Iter 2: ...
```

## Post-Execution Checks

After the bisect succeeds and the bundle deploys cleanly:

1. Verify all `# DEBUG-BISECT:` comment markers are removed (`grep -rn 'DEBUG-BISECT' modules/`).
2. Verify the canary's `nixos-rebuild list-generations` shows the resumed generation as active and prior generations are intact for rollback safety.
3. Update tasks.md if a NEW failure mode was discovered that future operators should know about — append a note to the bundle's canary task (T083 in spec 001) with a link to the debug report.

## Operating Principles

- **Read-only on commits**: never amend bundle commits during bisect; all bisect mutations live in the working tree until the fix is identified, then the fix is a NEW commit on top.
- **Smoke-test is the oracle**: do not declare a module "fine" without actually deploying + smoke-testing. Eval-passing ≠ runtime-passing (the post-mortem incident proved this).
- **Operator authority**: the bisect candidate ordering is a heuristic, not a mandate. If the operator has stronger priors, follow theirs.
- **No silent assumptions**: if the failure does not match any common pattern in step 4, say so. Do not guess.
