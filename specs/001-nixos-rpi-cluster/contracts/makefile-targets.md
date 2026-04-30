# Contract: Makefile targets

**Date**: 2026-04-29
**Spec**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md)

The Makefile is the operator interface for build, validation, and per-node operations within this spec. Every agent-driven and scripted invocation MUST go through these targets.

**Scope**: This contract covers only the targets that exist by end of this spec. Cluster-operations automation — automated single-command canary, cluster-wide rolling deploys, cluster-wide iteration helpers (`dry-run-all`, `smoke-test-all`), Pi-family build aliases, `encrypt-secret` (sops-nix integration) — is **out of scope** and is the subject of a future cluster-operations automation spec.

## Conventions

- `HOST=<host>` is required for any per-host target. Decommissioned-set hosts (`hlc-402..404`) accept `dry-run` and `build` only; all other host-targeting targets MUST refuse them with a clear message.
- **`IP` is derived from `HOST` by default.** HLC node IPs follow `hlc-VNN` → last octet on `10.23.50.0/24`:
  - `count ≤ 9`: octet = `V*10 + count` (e.g. `hlc-401` → 41, `hlc-509` → 59).
  - `count 10..19`: octet = `100 + V*10 + (count mod 10)` (e.g. `hlc-510` → 150, `hlc-419` → 149).

  Targets that talk to a live node compute `IP` from `HOST` automatically. Explicit `IP=<ip>` override is accepted for non-standard situations.
- `DEV=/dev/sdX` is required for `flash-image`. `REBUILD=1` is optional for `build-image`.
- All targets exit non-zero on failure. There is no auto-rollback within this spec; if a `make update-node` change leaves the node unhealthy, the operator runs `make rollback HOST=<host>` manually.
- The IP-derivation expression is a pure shell substitution (parsing `HOST` against `^hlc-([45])([0-9]{1,2})$`); no `docs/cluster-ips.txt` lookup file is required.

## Targets

### Inherited from `main` (Phase 0 baseline)

#### `make help`

Print all targets with one-line descriptions.

#### `make build-image HOST=<host> [REBUILD=1]`

Build the SD-card image for a host. `REBUILD=1` (added Phase 3 per FR-004) appends `--rebuild` to the underlying `nix build`, forcing re-realization regardless of the cache. Default invocation honors source-change cache invalidation (the post-mortem stale-image fix; the closure must include `modules/sd/bootstrap.nix` after Phase 3).

#### `make flash-image HOST=<host> DEV=/dev/sdX`

Build (if needed) then `dd` the SD image to a physical device. Refuses if `DEV` looks like a system disk.

#### `make silicon-dry`, `make silicon-switch`

Operator's laptop-specific dry-run / switch. `sudo nixos-rebuild dry-run --flake .#silicon` and `sudo nixos-rebuild switch --flake .#silicon`.

#### `make update`

`nix flake update`. Re-locks all flake inputs.

### Added Phase 2 Foundational

These four targets land together because every later phase's safety gate uses them.

#### `make dry-run HOST=<host>`

Single-host closure evaluation. On gibson, runs `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`. On silicon, runs `sudo nixos-rebuild dry-run --flake .#<host>`. Selection follows the host-capability table in Constitution VII.

**Pre-conditions**: None.
**Post-conditions**: Closure evaluable. No filesystem changes.
**Failure mode**: Non-zero exit with the Nix evaluation error.

#### `make build HOST=<host>`

Full toplevel build. `nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L`.

**Pre-conditions**: `dry-run` passed (operator discipline; not enforced).
**Post-conditions**: Toplevel derivation realized to the local Nix store.
**Failure mode**: Non-zero exit, Nix builder logs.

#### `make smoke-test HOST=<host> [IP=<ip>]`

Single-node reachability check. Resolves `IP` from `HOST` via the convention unless overridden. Steps in order:

1. Remove SSH host key entries for `<IP>` and `<HOST>` from `~/.ssh/known_hosts` (prevents stale-key failures after reflash).
2. `ssh bob@<IP> uname -a` (non-PTY) — MUST succeed.
3. `ssh bob@<HOST> uname -a` (non-PTY) — MUST succeed.

All steps MUST pass. No PTY (`-t` flag) — PTY mode caused Pi login hangs during testing; plain non-PTY SSH is the correct form.

**Pre-conditions**: Host has booted past the SD baseline (or post-provision steady state) and has the expected IP.
**Post-conditions**: Logs pass / fails specific step.
**Failure mode**: Non-zero exit naming which step failed.

#### `make ip HOST=<host>`

Print the IP for a host derived from its hostname. Pure derivation per the convention; no file lookup. Non-zero exit if `HOST` does not match the expected pattern.

### Added Phase 5 US3

#### `make provision HOST=<host> [IP=<ip>]`

Run `nixos-anywhere` against a freshly flashed and reachable node to install the full per-host configuration onto USB-RAID + (Pi 5) NVMe.

**Behavior**: Resolves `IP` via the convention unless overridden. Runs `nixos-anywhere --flake .#<host> --target-host root@<IP> --disko-mode disko`. The target's SD bootstrap image carries the operator's gibson SSH key as `root`'s authorized key for the duration of the install.

**Pre-conditions**:

- `make smoke-test HOST=<host>` green (the node is reachable on the SD baseline).
- USB drives + (Pi 5) NVMe physically attached.
- Disko schema (`disko/rpi{4,5}.nix`) selected by host family.
- Host is in the work-set (`hlc-401`, `hlc-501..508`). Decom-set hosts MUST be refused.

**Post-conditions**:

- USB array formatted as RAID1; NVMe formatted (Pi 5).
- Per-host NixOS config installed; node rebooted into new root.
- Subsequent SSH lands as `bob`, not `root`.

**Failure mode**: nixos-anywhere logs surfaced; SD baseline remains intact for retry.

**Idempotency** (FR-013): Re-running on a `provisioned` node is either a no-op (disko detects existing layout) or refuses with a clear message. Destructive re-provision requires explicit override (e.g. `MODE=destroy`).

### Added Phase 6 US4

These two targets land at the start of Phase 6 — first phase that does live-node config rollouts post-provisioning.

#### `make update-node HOST=<host> [IP=<ip>]`

Single-node `nixos-rebuild switch --target-host`. Wraps `sudo nixos-rebuild switch --flake .#<host> --target-host bob@<IP> --use-remote-sudo`. IP derives from HOST per the convention unless overridden.

**Pre-conditions**:

- Host is provisioned (post-Phase-5).
- Host is in the work-set; decom-set is refused.
- `bob` reachable, `sudo -n` works (W-002).
- `dry-run` and `build` already green for this host (operator discipline).

**Post-conditions**: New generation active on the target.
**Failure mode**: Non-zero exit. Operator runs `make rollback` if needed.

**Note**: This target does not auto-smoke-test or auto-rollback. Operator manually canaries by running `update-node` on one host, running `smoke-test`, and only then proceeding to the next host.

#### `make rollback HOST=<host> [IP=<ip>]`

Single-node `nixos-rebuild --rollback --target-host`. Wraps `sudo nixos-rebuild --rollback --flake .#<host> --target-host bob@<IP> --use-remote-sudo`.

**Pre-conditions**: Host has at least one prior generation.
**Post-conditions**: Previous generation active on the target.
**Failure mode**: Non-zero. NixOS boot-generation rollback at the console is always available as a final fallback.

## Out of scope (future cluster-operations automation spec)

These targets are explicitly **not** added by this spec:

- `canary HOST=<host>` — automated single-command canary (switch + smoke-test + auto-rollback). Within this spec, the operator does the canary by hand: `make update-node` on one node, then `make smoke-test`, then proceed (or `make rollback`).
- `update-cluster` — cluster-wide rolling deploy (canary first, then `update-node` on the rest).
- `dry-run-all`, `smoke-test-all` — cluster-wide iteration helpers.
- `build-image-rpi4`, `build-image-rpi5` — Pi-family convenience aliases. The parameterized `build-image HOST=<host>` form is canonical.
- `encrypt-secret` — sops-nix integration. Deferred per W-002 to a future secrets-management feature spec.
