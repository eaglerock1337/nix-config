# Contract: Makefile targets

**Date**: 2026-04-29
**Spec**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md)

The Makefile is the canonical operator interface (Constitution Principle VII). Every agent-driven and scripted invocation MUST go through these targets. This contract defines the targets in scope for this spec, their inputs, their behavior, and the gates they enforce.

## Conventions

- `HOST=<host>` is required for any per-host target. Decommissioned-set hosts (`hlc-402..404`) accept `dry-run` and `build` only; all other targets MUST refuse them with a clear message.
- **`IP` is derived from `HOST` by default.** HLC node IPs follow the rule: for hostname `hlc-VNN` (V = Pi version digit, NN = count within that version), the last octet on `10.23.50.0/24` is:
  - `count ≤ 9`: octet = `V*10 + count` (e.g. `hlc-401` → 41, `hlc-509` → 59).
  - `count 10..19`: octet = `100 + V*10 + (count mod 10)` (e.g. `hlc-510` → 150, `hlc-511` → 151, `hlc-419` → 149).

  Targets that talk to a live node compute `IP` from `HOST` automatically. An explicit `IP=<ip>` override is accepted for non-standard situations (e.g. a node temporarily on a DHCP-assigned address, recovery from a misconfigured reservation).
- `DEV=/dev/sdX` is required for `flash-image`. `REBUILD=1` is optional for `build-image`.
- All targets exit non-zero on failure. Smoke-test failures auto-trigger rollback only inside `canary`.
- The IP-derivation expression in the Makefile is a pure shell substitution (parsing `HOST` against `^hlc-([45])([0-9]{2})$`); no `docs/cluster-ips.txt` lookup file is required.

## Build & validate

### `make dry-run HOST=<host>`

**Purpose**: Verify a host's NixOS configuration evaluates and produces a closure.

**Behavior**: On gibson, runs `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run` (or equivalent). On silicon, runs `sudo nixos-rebuild dry-run --flake .#<host>`. Selection follows the host-capability table in Constitution VII.

**Pre-conditions**: None.

**Post-conditions**: Closure evaluable. No filesystem changes.

**Failure mode**: Exits non-zero with the Nix evaluation error.

---

### `make build HOST=<host>`

**Purpose**: Full toplevel build (closure realized). Catches build-time errors that dry-run misses.

**Behavior**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L`.

**Pre-conditions**: `dry-run` passed (operator discipline; not enforced).

**Post-conditions**: Toplevel derivation realized to the local Nix store.

**Failure mode**: Non-zero exit, Nix builder logs.

---

### `make build-image HOST=<host> [REBUILD=1]`

**Purpose**: Build the SD-card image for a host. Default uses the build cache; `REBUILD=1` forces re-realization.

**Behavior**: `nix build .#nixosConfigurations.<host>.config.system.build.sdImage -L` (with `--rebuild` when `REBUILD=1`).

**Pre-conditions**: Host's `configuration.nix` includes the SD image module (typically inherited from `modules/cluster/common.nix` for cluster nodes during the bootstrap phase).

**Post-conditions**: Image artifact in `result/sd-image/*.img.zst`. The derivation closure correctly depends on `modules/sd/bootstrap.nix` so changes to bootstrap source invalidate the cache (FR-004).

**Failure mode**: Non-zero. If a stale image is suspected, retry with `REBUILD=1`.

---

### `make build-image-rpi4` / `make build-image-rpi5`

**Purpose**: Convenience aliases for the two canonical builds (`hlc-401` for Pi 4, `hlc-501` for Pi 5).

**Behavior**: Equivalent to `make build-image HOST=hlc-401` / `HOST=hlc-501`.

## Flash & provision

### `make flash-image HOST=<host> DEV=/dev/sdX`

**Purpose**: Build (if needed) and flash the SD image to a physical device.

**Behavior**: Depends on `build-image`. Then `zstd -d` the result and `dd` (or `bmaptool`) to `DEV`. Refuses if `DEV` looks like a system disk (basic safety check).

**Pre-conditions**: `DEV` is a removable USB SD-card writer. Host's flake config builds an SD image.

**Post-conditions**: Bootable SD card with the bootstrap image written to `DEV`.

**Failure mode**: Non-zero. Common causes: wrong `DEV`, permission denied (needs `sudo`), zstd decompression error.

---

### `make smoke-test HOST=<host> [IP=<ip>]`

**Purpose**: Confirm a node is reachable and meets the basic interactive-shell contract.

**Behavior**: Resolves `IP` from `HOST` via the convention unless overridden. Then: ping `IP` → non-PTY ssh `bob@<IP> true` → PTY ssh (TTY allocated) → `ssh bob@<IP> sudo -n true`. All four MUST pass.

**Pre-conditions**: Host has booted past the SD baseline (or post-provision steady state) and has the expected IP (DHCP reservation enforces the convention).

**Post-conditions**: Logs success or specific failure reason.

**Failure mode**: Non-zero with which step failed (ping / non-PTY / PTY / sudo).

---

### `make smoke-test-all`

**Purpose**: Smoke-test every WORK_SET host using the IP-derivation convention.

**Behavior**: Iterates the 9 work-set hosts; for each, derives the IP from the hostname and runs `smoke-test`. Reports pass/fail per host; non-zero exit if any fail.

---

### `make provision HOST=<host> [IP=<ip>]`

**Purpose**: Run `nixos-anywhere` against a freshly flashed and reachable node to install the full per-host NixOS configuration onto USB-RAID + NVMe.

**Behavior**: Resolves `IP` from `HOST` via the convention unless overridden. Runs `nixos-anywhere --flake .#<host> --target-host root@<IP> --disko-mode disko`. The target's SD bootstrap image carries the operator's gibson SSH key as `root`'s authorized key for the duration of the install.

**Pre-conditions**:

- `make smoke-test HOST=<host>` green (the node is reachable).
- Two USB drives plus (Pi 5) NVMe physically attached. Disko schema (`disko/rpi{4,5}.nix`) selected by host family.
- Host is in WORK_SET. Decommissioned-set hosts MUST be refused.

**Post-conditions**:

- USB array formatted as RAID1; NVMe formatted (Pi 5).
- Per-host NixOS config installed; node rebooted into new root.
- Subsequent SSH lands as `bob`, not `root`.

**Failure mode**: nixos-anywhere logs surfaced; SD baseline remains intact for retry.

**Idempotency**: Re-running on a `provisioned` node is either a no-op (disko detects existing layout) or refuses with a clear message (FR-013). A destructive re-provision requires explicit override (e.g. `MODE=destroy`).

## Update & rollout

### `make canary HOST=<host> [IP=<ip>]`

**Purpose**: Apply a configuration change to a single node with auto-rollback on smoke-test failure.

**Behavior**: Resolves `IP` from `HOST` via the convention unless overridden. `make build HOST=<host>` → `nixos-rebuild switch --flake .#<host> --target-host bob@<IP> --use-remote-sudo` → `make smoke-test HOST=<host>` → on failure, automatic `nixos-rebuild switch --rollback` over SSH and re-run smoke-test.

**Pre-conditions**:

- Host is in WORK_SET (decommissioned-set is forbidden).
- `bob` reachable; `sudo -n` works (W-002).
- `dry-run` and `build` already green (operator discipline).

**Post-conditions** on success: New generation active; smoke-test green.
**Post-conditions** on failure: Rolled back to previous generation; smoke-test green again; non-zero exit so the operator stops the rollout.

**Why this gate is mandatory**: Constitution Principle IV requires canary-first deployment for any cluster-touching change.

---

### `make rollback HOST=<host> [IP=<ip>]`

**Purpose**: Manually roll a node back to its previous generation and re-run smoke-test.

**Behavior**: Resolves `IP` from `HOST` via the convention unless overridden. Runs `nixos-rebuild switch --rollback --flake .#<host> --target-host bob@<IP> --use-remote-sudo` then `make smoke-test`.

**Pre-conditions**: Host has at least one prior generation.

**Post-conditions**: Previous generation active.

---

### `make update-node HOST=<host> [IP=<ip>]`

**Purpose**: Plain `nixos-rebuild switch` against a single node, **without** the canary smoke-test gate. Permitted only for nodes that have been canary-tested in another rotation slot.

**Behavior**: Resolves `IP` from `HOST` via the convention unless overridden. Runs `nixos-rebuild switch --flake .#<host> --target-host bob@<IP> --use-remote-sudo`.

**Pre-conditions**: Operator has already canaried the change on a different host.

**Post-conditions**: New generation active.

**Caution**: Bypasses the smoke-test auto-rollback. Use sparingly during rolling updates after the canary pass has gated the change.

---

### `make update-cluster`

**Purpose**: Roll the current configuration across all 9 work-set nodes serially (canary first, then update-node for the rest).

**Behavior**: Pick a canary host (default `hlc-501`); `make canary` against it; on success, `make update-node` against the remaining 8 work-set hosts in a documented order. Smoke-test after each. All targets compute their IPs from hostnames.

**Pre-conditions**: Configuration changes are committed and pushed (gibson-driven); host is in WORK_SET.

**Post-conditions**: All 9 work-set nodes on the new generation; smoke-test green on each.

## Convenience

### `make ip HOST=<host>`

**Purpose**: Print the IP for a host derived from its hostname.

**Behavior**: Pure derivation per the convention in this contract's Conventions section. No file lookup. Non-zero exit if `HOST` does not match `^hlc-[45][0-9]{2}$`.

---

### `make encrypt-secret`

**Purpose**: Encrypt a secret for the cluster age recipients (placeholder; sops-nix integration deferred per W-002).

**Behavior**: Stub that exists for API stability with the future secrets-mgmt feature spec. Currently prints "deferred — sops-nix not yet wired up" and exits non-zero.

**Pre-conditions**: None.

**Post-conditions**: None (deferred).

**Why exists**: FR-024 requires the *target* to exist for MVP completeness even when its implementation is deferred.

---

### `make silicon-dry` / `make silicon-switch`

**Purpose**: Operator's laptop-specific dry-run / switch. Pre-existing.

**Behavior**: `sudo nixos-rebuild dry-run --flake .#silicon` / `sudo nixos-rebuild switch --flake .#silicon`.

---

### `make help`

**Purpose**: Print all targets with one-line descriptions. The single source of truth for the operator-visible CLI.
