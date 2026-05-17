---
name: "speckit-debug"
description: "General-purpose debugging skill for any failure encountered during speckit-driven work. Trigger when a Makefile target fails, a deploy breaks, a build errors out, provisioning goes wrong, or any other issue blocks progress on the current spec. Covers provisioning failures, bootloader issues, evaluation errors, runtime failures, smoke-test regressions, and more. Also use when the user says 'debug this', 'what went wrong', 'fix this error', or invokes /speckit-debug."
argument-hint: "Describe the failure: paste the error output, which make target failed, what HOST was involved, and any relevant context about what you were doing when it broke."
compatibility: "Requires spec-kit project structure. Works with any Makefile target, NixOS build, or deploy step in the project."
metadata:
  author: "peter.marks@betterment.com"
  source: "specs/001-nixos-rpi-cluster"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** read and analyze the user's error output before proceeding. The user's description of what they were doing and what failed is your starting point.

## Context

This skill is the general debugging path for any failure that occurs during speckit-driven implementation work. Failures can happen at any stage: Nix evaluation, building closures, provisioning nodes, deploying updates, installing bootloaders, activating configurations, running smoke-tests, etc.

Your job is to **diagnose the root cause** and **propose a fix**. You are an SRE working alongside the operator — investigate methodically, surface findings clearly, and don't guess.

## Hostname convention

**Short HLC hostnames do NOT resolve over SSH from the operator workstation.** Always use the FQDN form `<host>.marks.dev` (e.g. `hlc-501.marks.dev`) for any direct `ssh` command. The Makefile already composes FQDN internally (`bob@$(HOST).$(HLC_DOMAIN)`), so `make` targets that take `HOST=hlc-501` are fine — but any raw `ssh` invocation must use FQDN.

## Debugging Process

### 1. Understand the failure

- Read the error output carefully. Identify:
  - Which Makefile target or command failed
  - Which host was involved
  - The specific error message (not just "it failed")
  - What stage of the process it was in (eval, build, copy, install, activate, reboot)

### 2. Gather context

- Read the relevant Makefile target to understand what commands are being run
- Read the relevant NixOS/disko/hardware configuration files
- Check the plan (`specs/001-nixos-rpi-cluster/plan.md`) for expected behavior
- Check `specs/WORKAROUNDS.md` for known issues that may be related
- If the host is reachable, gather state from it (mounts, services, logs) via SSH

### 3. Form a hypothesis

Based on the error and context, identify the most likely root cause. Common failure categories:

**Provisioning failures:**
- Filesystem not mounted (disko didn't run, or mount point missing)
- Bootloader install fails (boot partition not mounted, wrong path, firmware files missing)
- nixos-anywhere phase ordering issues (install before disko, etc.)
- Closure too large for SD-booted Pi (RAM/disk constraints)

**Build/evaluation errors:**
- Module option type mismatch
- Missing imports or circular dependencies
- Unfree package not in allowlist
- Flake input not available or outdated

**Deploy/update failures:**
- SSH connectivity (key issues, host not reachable, wrong user)
- Activation script failures (file collisions, permission issues)
- Service startup failures post-switch
- Boot generation issues

**Smoke-test regressions:**
- SSH login broken (auth config, keys, user config)
- sudo not working (wheel group, sudoers config)
- Network not configured properly after switch

### 4. Investigate and verify

- Read the specific files implicated by the error
- If needed, check the host state via SSH
- Run `make dry-run HOST=<host>` to check for eval issues
- Cross-reference with git history to see what changed recently

### 5. Report findings

Present to the operator:
- **Root cause**: What specifically is wrong
- **Evidence**: The file(s) and line(s) involved
- **Proposed fix**: What to change and why
- **Risk assessment**: Could the fix break something else?

### 6. Apply fix (with operator approval)

After the operator approves:
1. Make the minimal edit to fix the issue
2. Run `make dry-run HOST=<host>` to verify eval passes
3. If appropriate, re-run the failed make target
4. Verify success
5. Commit the fix as a new commit (do NOT amend existing commits)

## Escalation

Escalate to the operator (do NOT proceed silently) when:

- The failure doesn't match any pattern you can identify from the code
- Multiple interacting causes seem involved
- The fix would require architectural changes beyond a simple edit
- You need information not available in the repo (e.g., physical hardware state, network config outside this repo)
- Constitution VIII applies: surface uncertainty, do not silently rewrite the operator's working theory

## Report Format

```markdown
## /speckit-debug Report

**Failed step**: <make target or command>
**Host**: <hostname, if applicable>
**Root cause**: <one-line summary>
**Evidence**: <file:line references>
**Fix applied**: <description of change, or "pending operator approval">
**Verification**: <what was run to confirm the fix>
```

## Operating Principles

- **Investigate before acting**: Read the error, read the code, form a hypothesis, then act.
- **Minimal fixes**: Fix what's broken. Don't refactor, don't improve, don't clean up.
- **Operator authority**: Present findings and proposed fixes. Let the operator decide on non-obvious choices.
- **No silent assumptions**: If the failure is ambiguous, say so. Don't guess.
- **Preserve history**: Fixes are new commits, not amends.
