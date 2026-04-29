# Workarounds Ledger

Per current constitution § Pragmatic Phasing (Principle V). Each entry is
append-only; mark `Resolved` in-place when removed. Reviewed at every
phase-exit gate and every `/speckit-plan` cycle.

---

## W-001: Inline minimal host configs (defers Principle III)

- **Site(s)**: After Phase 0 baseline reset, only `hosts/hlc-501/configuration.nix` and `hosts/silicon/*` exist (matching `main`). As Phase 3 re-adds the work-set hosts (`hlc-401`, `hlc-502..508`) and the decom-set host configs (`hlc-402..404`, dry-run-only per Constitution §"Cluster Topology"), each new `hosts/hlc-NNN/configuration.nix` is brought up as a thin per-host file plus inline minimal config until Phase 5 reintroduces the shared modules.
- **Deviates from**: Constitution Principle III (Modular Design)
- **Reason**: The previous attempt to land shared modules + 12 hosts in one push produced a non-recoverable bricked node (hlc-508) and an interactive-ssh hang that did not reproduce in dry-run. Inlining a minimal canonical config per host gives zero blast radius per host and lets us isolate any future module regression to the exact module being reintroduced.
- **Exit condition**: The operator-UX modules (`modules/shell/utilities.nix` toolbox, `modules/shell/common.nix` bash baseline, `modules/shell/prompt.nix` PS1, `modules/motd/default.nix`, `modules/cluster/hlc/motd-banner.nix`, `modules/users/operator.nix`, home-manager modular split, SSH hardening) are reintroduced as a **phase-bundle** per [plan.md → Phase 5](./specs/001-nixos-rpi-cluster/plan.md) and Constitution v1.3.2 §IV "Canary scope". `/speckit-implement` runs all module-creation tasks for the phase, then a single canary on `hlc-501` via `make update-node` + `make smoke-test`. On smoke-test fail: `/speckit-debug` skill drives rollback + incremental reintroduction (comment-out / git-revert new modules one at a time, redeploy, smoke-test) to bisect the breaking module. On smoke-test green: serial fleet roll across `hlc-502..508` then `hlc-401`, smoke-test after each.
- **Target phase / feature**: This spec's Phase 5 (Operator UX). The bundle's single canary closes the inline-host approach across all six modules at once; W-001 is fully Resolved when Phase 5 exits with all 9 work-set nodes on the bundled modular configuration. The post-mortem lesson (regression isolation) is preserved by the bisect-on-fail flow rather than by per-module cadence.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-002: Passwordless `wheel` sudo (`security.sudo.wheelNeedsPassword = false`)

- **Site(s)**: After Phase 0, no inline `security.sudo` settings exist on any host (silicon + `main`'s `hlc-501`). As Phase 5 reintroduces `modules/users/operator.nix`, `bob`'s passwordless wheel landed there. Future per-host sites: every node that imports the operator module.
- **Deviates from**: Eventual passwordless-via-key+sops hardened state
- **Reason**: `nixos-rebuild switch --target-host bob@<ip> --use-remote-sudo` (the canary remote-update path) requires `sudo -n true` to succeed without an interactive password prompt. Sops-managed credentials are not yet provisioned. Passwordless wheel on a key-only-ssh node is the standard NixOS bring-up posture; closes when secrets management lands.
- **Exit condition**: sops-nix integration deployed; bob's sudo authorization driven by an age-decrypted credential or an alternate hardened mechanism.
- **Target phase / feature**: Future feature spec — secrets-management spec (`/speckit-specify` not yet run). Out of scope for the current /speckit-plan cycle.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-003: Default `PasswordAuthentication = true` (NixOS 25.11 sshd default)

- **Site(s)**: After Phase 0, no per-host SSH hardening exists; `services.openssh.settings.PasswordAuthentication` retains its NixOS default. Reintroduced explicitly in Phase 5 SSH-hardening sub-step on all 9 work-set hosts (decom-set hosts not flashed; not in scope).
- **Deviates from**: Spec FR-020 (`password authentication MUST be off post-provisioning`)
- **Reason**: Operator explicitly opted to keep password auth enabled as a short-term fallback during initial bring-up. Rationale: a misconfigured `authorized_keys` block (typo, key file path bug, encoding error) on a headless rack node would otherwise brick the node at first boot. Until at least one node has been validated end-to-end with key-only login, password auth provides recovery. Risk accepted on the basis that `bob` has no password set (NixOS defaults disable password login when no password hash exists), so the remaining attack surface is keyboard-interactive auth attempts which an attacker on the management subnet could attempt — explicit known risk.
- **Exit condition**: SSH hardening sub-step in Phase 5 deploys `services.openssh.settings.PasswordAuthentication = false` and `KbdInteractiveAuthentication = false` to all 9 work-set nodes via canary, smoke-test green.
- **Target phase / feature**: Phase 5 (Operator UX) — SSH hardening is the last sub-step of that phase and closes both this entry and W-001.
- **Opened**: 2026-04-26
- **Resolved**: (open)
