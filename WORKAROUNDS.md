# Workarounds Ledger

Per constitution v1.1.0 § Pragmatic Phasing (Principle V). Each entry is
append-only; mark `Resolved` in-place when removed. Reviewed at every
phase-exit gate and every `/speckit-plan` cycle.

---

## W-001: Inline minimal host configs (defers Principle III)

- **Site(s)**: `hosts/hlc-401/configuration.nix`, `hosts/hlc-501/configuration.nix` through `hosts/hlc-508/configuration.nix` (work-set), `hosts/hlc-402/configuration.nix` through `hosts/hlc-404/configuration.nix` (decommissioned-set, dry-run only)
- **Deviates from**: Constitution Principle III (Modular Design)
- **Reason**: Previous attempt to land shared modules + 12 hosts in one push produced a non-recoverable bricked node (hlc-508) and an interactive-ssh hang that does not reproduce in dry-run. Inlining ~12 lines of canonical config per host gives zero blast radius per host and lets us isolate any future module regression to the exact module being reintroduced.
- **Exit condition**: All six modules (operator, shell/common, shell/prompt, shell/utilities, motd, ssh hardening) reintroduced one at a time via canary deploys (Phase 7a–7f), each with smoke-test gate, all 9 work-set nodes green.
- **Target phase / feature**: Phase 7a closes module 1 (operator); each subsequent sub-phase removes inline state for that module. W-001 itself closes when Phase 7f exit gate passes.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-002: Passwordless `wheel` sudo (`security.sudo.wheelNeedsPassword = false`)

- **Site(s)**: All 12 host configs in Phase 4 baseline; later moves into `modules/users/operator.nix` (Phase 7a T080) without changing semantics
- **Deviates from**: Eventual passwordless-via-key+sops hardened state
- **Reason**: `nixos-rebuild switch --target-host bob@<ip> --use-remote-sudo` (the canary remote-update path) requires `sudo -n true` to succeed without an interactive password prompt. Sops-managed credentials are not yet provisioned. Passwordless wheel on a key-only-ssh node is the standard NixOS bring-up posture; closes when secrets management lands.
- **Exit condition**: sops-nix integration deployed; bob's sudo authorization driven by an age-decrypted credential or an alternate hardened mechanism.
- **Target phase / feature**: Future feature spec — Phase D (disko + sops + secrets). Out of scope for the current /speckit-plan cycle.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-003: Default `PasswordAuthentication = true` (NixOS 25.11 sshd default)

- **Site(s)**: All 9 work-set host configs in Phase 4 baseline (decom-set hosts not flashed; not in scope)
- **Deviates from**: Spec FR-011 (`password authentication MUST be disabled`)
- **Reason**: Operator explicitly opted to keep password auth enabled as a short-term fallback during initial bring-up. Rationale: a misconfigured `authorized_keys` block (typo, key file path bug, encoding error) on a headless rack node would otherwise brick the node at first boot. Until at least one node has been validated end-to-end with key-only login, password auth provides recovery. Risk accepted on the basis that `bob` has no password set (NixOS defaults disable password login when no password hash exists), so the remaining attack surface is keyboard-interactive auth attempts which an attacker on the management subnet could attempt — explicit known risk.
- **Exit condition**: SSH hardening module (T104, Phase 7f) deploys `services.openssh.settings.PasswordAuthentication = false` and `KbdInteractiveAuthentication = false` to all 9 work-set nodes via canary, smoke-test green.
- **Target phase / feature**: Phase 7f tasks T104–T108. T108 marks this entry Resolved.
- **Opened**: 2026-04-26
- **Resolved**: (open)
