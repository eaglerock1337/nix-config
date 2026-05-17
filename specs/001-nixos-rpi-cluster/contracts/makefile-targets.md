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

### Inherited from `main` (pre-spec baseline)

#### `make help`

Print all targets with one-line descriptions.

#### `make build-image HOST=<host> [REBUILD=1]`

Build the SD-card image for a host. `REBUILD=1` (added Phase 3 / US1 per FR-004) appends `--rebuild` to the underlying `nix build`, forcing re-realization regardless of the cache. Default invocation honors source-change cache invalidation (the post-mortem stale-image fix; the closure must include `modules/sd/bootstrap.nix` after Phase 3).

#### `make flash-image HOST=<host> DEV=/dev/sdX`

Build (if needed) then `dd` the SD image to a physical device. Refuses if `DEV` looks like a system disk.

#### `make silicon-dry`, `make silicon-switch`

Operator's laptop-specific dry-run / switch. `sudo nixos-rebuild dry-run --flake .#silicon` and `sudo nixos-rebuild switch --flake .#silicon`.

#### `make update`

`nix flake update`. Re-locks all flake inputs.

### Added Phase 1 (Foundational)

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

### Added Phase 5 (US3)

#### `make provision HOST=<host> [IP=<ip>]`

Two-phase provisioning: install a provision-minimal NixOS config via `nixos-anywhere`, then push the full per-host config via `update-node`. Composite target running: `provision-stage1` → `provision-mount` → `provision-stage2` → `smoke-test` → `provision-stage3` → `smoke-test`.

**Behavior**: Resolves `IP` via the convention unless overridden. Stage 1 runs disko (partition + format). Stage 2 runs `nixos-anywhere --flake .#<host>-provision` (provision-minimal config — SSH + bob + nix + RAID boot; no home-manager, toolbox, MOTD, or PS1). Mid-flow smoke-test clears stale SSH host keys and verifies SSH reachability after reboot. Stage 3 runs `update-node` to push the full `.#<host>` config as a differential `nix copy`.

**Pre-conditions**:

- `make smoke-test HOST=<host>` green (the node is reachable on the SD baseline).
- USB drives + (Pi 5) NVMe physically attached.
- Disko schema (`disko/rpi{4,5}.nix`) selected by host family.
- Host is in the work-set (`hlc-401`, `hlc-501..508`). Decom-set hosts MUST be refused.

**Post-conditions**:

- USB array formatted as RAID1; NVMe formatted (Pi 5).
- Full per-host NixOS config installed; node rebooted into new root.
- Subsequent SSH lands as `bob`, not `root`.

**Failure mode**: nixos-anywhere logs surfaced; SD baseline remains intact for retry. If stage 3 fails (full config push), node remains SSH-reachable on provision-minimal config; operator retries `make provision-stage3 HOST=<host>` or `make update-node HOST=<host>` without re-provisioning.

**Idempotency** (FR-013): `make provision` includes a pre-flight RAID check (`check_raid_clear`) before running any disko or nixos-anywhere step. It SSHes to the target as `bob` and checks whether (a) the root filesystem device contains `md` (RAID-backed root = live provisioned node) or (b) any md array is assembled in `/proc/mdstat`. If either condition is true, the target exits non-zero with a clear message: `ERROR: <host> has active RAID or md root filesystem — live provisioned node detected.` The SD baseline remains intact for retry. This behavior was validated in T039 (2026-05-11): re-running `make provision` on a live provisioned node is now refused rather than destructively re-provisioned.

**Note on SSH safety gate**: The check uses output comparison rather than exit-code inspection so that an unreachable host (SSH error) also fails the pre-flight (empty output ≠ `CLEAR` → exit 1). Fail-closed by design.

#### `make provision-stage3 HOST=<host> [IP=<ip>]`

Wait for node to come back online after stage 2 reboot, then push full config via `update-node`. Retriable independently — if this fails, the node is on provision-minimal config (SSH-reachable) and the operator re-runs this target.

**Pre-conditions**: Stage 2 completed; node rebooting from provision-minimal config on USB RAID.
**Post-conditions**: Full per-host config active on node.
**Failure mode**: Non-zero exit. Node remains on provision-minimal config (SSH-reachable); operator retries.

#### `make reprovision HOST=<host> [IP=<ip>]`

Reprovision USB RAID only, preserving existing NVMe data at `/srv`. Use when USB drives need to be reformatted (e.g. array corruption) but the NVMe holds cluster data that must not be wiped.

**Behavior**: Same RAID pre-flight check as `make provision`. Runs disko using `.#<host>-bare` flake output (NVMe excluded from disko schema via `hlc.disko.skipNvmeFormat = true`), then mounts `/boot/firmware`, then runs the install phase using `.#<host>-provision` (provision-minimal config; NVMe back in disko schema via default `skipNvmeFormat = false` so the installed fstab includes `/srv`). After reboot, `provision-stage3` pushes the full config. The existing NVMe filesystem is mounted but never reformatted.

**Pre-conditions**:
- Node is on SD baseline (no RAID assembled — same gate as `make provision`).
- NVMe previously partitioned and formatted by a prior `make provision` run (i.e. this is a re-provision, not first-time).
- Host is in the Pi 5 work-set; Pi 4 nodes have no NVMe and should use `make provision`.

**Post-conditions**: USB RAID reformatted; NVMe data preserved; node rebooted into new root with `/srv` intact.

**Failure mode**: Same as `make provision`.

#### `make reprovision-stage1 HOST=<host> [IP=<ip>]`

Disko phase of `make reprovision` — formats USB RAID only (NVMe excluded). Not normally invoked directly; called by `make reprovision`.

#### `make provision-reinstall HOST=<host> [IP=<ip>]`

RAID-retry path for failed stage2 where disko succeeded but the nixos-anywhere install phase failed or timed out. The RAID array exists but has no NixOS installed; the node rebooted to the SD baseline.

**Behavior**: Resolves `IP` via the convention unless overridden. Pre-flight: SSH to node, verify RAID array exists in `/proc/mdstat` but root is NOT md-backed (booted from SD — distinguishes "disko ran, install failed" from "fully provisioned node"). If root IS md-backed, exits non-zero: `ERROR: <host> has md-backed root — use make update-node instead.` If no RAID exists, exits non-zero: `ERROR: <host> has no RAID array — use make provision instead.` Skips `provision-stage1` (disko already done). Runs `provision-mount` → `provision-stage2` → `smoke-test` → `provision-stage3` → `smoke-test`.

**Pre-conditions**:

- Node booted from SD baseline (not RAID root).
- RAID array exists in `/proc/mdstat` (disko ran previously).
- Host is in the work-set. Decom-set hosts MUST be refused.

**Post-conditions**: Same as `make provision` — full per-host NixOS config installed; node rebooted into new root.

**Failure mode**: Same as `make provision`. SD baseline remains intact for retry.

### Added Phase 5 (US3) — live-node operations

These targets land in Phase 5 because `provision-stage3` depends on `update-node`. Also used in Phase 6+ for config updates and canary validation.

#### `make update-node HOST=<host> [IP=<ip>]`

Single-node local build + `nix copy` + remote activate. Builds `.#nixosConfigurations.<host>.config.system.build.toplevel` locally, copies the closure to the remote node via `nix copy --to ssh-ng://bob@<IP>`, then activates via `switch-to-configuration switch`. IP derives from HOST per the convention unless overridden.

**Pre-conditions**:

- Host is provisioned (post-Phase-5 / US3).
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

### Added Phase 5 (US3) — disaster recovery operations

These targets support the initrd rescue shell (dropbear SSH as `root@`) and the `hlc-recover` script available in the initrd when RAID fails to assemble.

#### `make provision-backup-boot HOST=<host>`

Backup SD firmware partition contents before `provision-stage2` overwrites them with provisioned NixOS boot files. Creates `.bootstrap-backup.tar.gz` on the firmware partition, enabling `hlc-recover sd-boot` in the initrd rescue shell without requiring a full SD reflash.

**Pre-conditions**: `provision-mount` has run (firmware partition mounted at `/mnt/boot/firmware`).
**Post-conditions**: `.bootstrap-backup.tar.gz` exists on the firmware partition.
**Failure mode**: Non-zero exit if firmware partition not mounted or tar fails.

#### `make recover-status HOST=<host>`

Query initrd rescue node state. Connects as `root@<HOST>.<DOMAIN>` (dropbear SSH in initrd) and runs `hlc-recover status` which reports block devices, blkid, RAID state, and mount points.

**Pre-conditions**: Node is in initrd rescue mode (RAID failed to assemble; dropbear running).
**Post-conditions**: Status output printed to operator console.
**Failure mode**: Non-zero exit if SSH connection fails (node may not be in rescue mode).

#### `make recover-wipe HOST=<host>`

Wipe RAID on an initrd rescue node. Prompts for confirmation, then connects as `root@` and runs `hlc-recover wipe -y` (stops arrays, zeros superblocks, wipefs, sgdisk on all `/dev/sd?` devices).

**Pre-conditions**: Node is in initrd rescue mode.
**Post-conditions**: USB drives fully wiped; ready for reprovisioning.
**Failure mode**: Non-zero exit on SSH failure. Operator confirmation gate prevents accidental execution.

#### `make recover-sd-boot HOST=<host>`

Restore SD bootstrap boot files on an initrd rescue node. Connects as `root@` and runs `hlc-recover sd-boot` which extracts the `.bootstrap-backup.tar.gz` created by `provision-backup-boot` onto the firmware partition, restoring the original SD bootstrap kernel/initrd.

**Pre-conditions**: Node is in initrd rescue mode; `.bootstrap-backup.tar.gz` exists on firmware partition.
**Post-conditions**: SD card firmware partition contains original bootstrap boot files; `reboot -f` will boot into SD bootstrap.
**Failure mode**: Non-zero exit if backup tarball not found (node provisioned before backup feature; requires full SD reflash).

#### `make recover HOST=<host>`

Full recovery cycle for a node stuck in initrd rescue. Composite: wipe RAID → restore SD boot → reboot → wait for SD bootstrap → provision (full two-phase flow). Prompts for confirmation before starting.

**Pre-conditions**: Node is in initrd rescue mode (dropbear SSH reachable as `root@`).
**Post-conditions**: Node fully reprovisioned (same as `make provision` post-conditions).
**Failure mode**: Non-zero exit at any stage. Partial progress is safe — operator can resume at the appropriate step manually.

## Out of scope (future cluster-operations automation spec)

These targets are explicitly **not** added by this spec:

- `canary HOST=<host>` — automated single-command canary (switch + smoke-test + auto-rollback). Within this spec, the operator does the canary by hand: `make update-node` on one node, then `make smoke-test`, then proceed (or `make rollback`).
- `update-cluster` — cluster-wide rolling deploy (canary first, then `update-node` on the rest).
- `dry-run-all`, `smoke-test-all` — cluster-wide iteration helpers.
- `build-image-rpi4`, `build-image-rpi5` — Pi-family convenience aliases. The parameterized `build-image HOST=<host>` form is canonical.
- `encrypt-secret` — sops-nix integration. Deferred per W-002 to a future secrets-management feature spec.
