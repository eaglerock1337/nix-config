# Phase 1 Data Model: NixOS RPi Cluster Foundation (v2)

**Date**: 2026-04-29
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

This is a NixOS-config repo, not an application; "data" here means the entities the config layer manipulates: hosts, users, disks, modules, secrets, build artifacts. Each entity below is described by the attributes that are load-bearing (have at least one functional requirement, success criterion, or build-target depending on them) and by the relationships that drive module composition.

---

## Cluster Node

A physical Raspberry Pi managed by this repo.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `hostname` | string | One of `hlc-401..404`, `hlc-501..508`. Short hostname; FQDN is `<hostname>.marks.dev`. |
| `family` | enum `rpi4` \| `rpi5` | Drives device-scope module selection (`modules/hardware/rpi4.nix` vs `rpi5.nix`). |
| `role` | enum `control-plane` \| `worker` | `hlc-401..404` are control-plane; `hlc-501..508` are workers. Used by `modules/cluster/common.nix` (and the future cluster-bootstrap spec) for k3s server/agent selection. |
| `inScope` | bool | True for `hlc-401`, `hlc-501..508` (the 9 work-set hosts). False for `hlc-402..404` (decommissioned-set; configs evaluable, never flashed). Drives Makefile gating. |
| `ip` | IPv4 | Static-DHCP-reserved address on `10.23.50.0/24`, **derived** from `hostname` per the HLC IP convention (`hlc-VNN` → octet computed from `V` and `count`; see [contracts/makefile-targets.md](./contracts/makefile-targets.md) Conventions section). Not stored in a lookup file. |
| `mac` | string | MAC of the on-board Ethernet, used for the DHCP reservation. |
| `usbDevice0` / `usbDevice1` | `/dev/disk/by-id/...` | The two USB drives that form the RAID1 mirror. |
| `nvmeDevice` | `/dev/disk/by-id/...` \| null | NVMe drive identifier; null on Pi 4 nodes. |
| `bootEepromBootOrder` | hex (e.g. `0xf14`) | EEPROM `BOOT_ORDER` value. Set once via `rpi-eeprom-config` during SD baseline. |

**Lifecycle**:

`unbuilt` → `flashed` (SD baseline written) → `reachable` (SSH from gibson, smoke-test green) → `provisioned` (nixos-anywhere installed, USB array online) → `live` (per-host config applied via `make update-node` + `make smoke-test`; on failure `make rollback`).

For decommissioned-set hosts (`inScope = false`): lifecycle is bounded at `unbuilt → dry-run-only`. Any attempt to take them past `flashed` is a constitution violation (Cluster Topology section).

**Relationships**:

- One Cluster Node has one **NixOS Configuration** (per-host module at `hosts/<hostname>/configuration.nix`).
- One Cluster Node has zero or one **Disko Schema** binding (Pi 4 → `disko/rpi4.nix`; Pi 5 → `disko/rpi5.nix`).
- One Cluster Node has exactly one **Operator User** (`bob`).

---

## Workstation Node

The operator's local machine(s); not a cluster node, but managed by this repo.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `hostname` | string | `silicon` (laptop, NixOS); `gibson` is the build host but not currently a NixOS box (constitution Principle VII host-capability table). |
| `family` | enum `x1-carbon` \| `gibson` \| ... | Drives `modules/hardware/<family>.nix`. |
| `operator` | string | `eaglerock`. |
| `homeManagerProfile` | enum `workstation` | Pulls `modules/home/workstation.nix`. |

**Relationships**:

- One Workstation Node has exactly one **Operator User** (`eaglerock`).
- Workstation Nodes share the **Sysadmin Toolbox** module with all Cluster Nodes; this is the only point of overlap with the cluster scope.

---

## Operator User

A NixOS user account.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `username` | string | `bob` (cluster) or `eaglerock` (workstation). |
| `authorizedKeys` | list[string] | SSH public keys allowed to log in. For MVP, hardcoded in NixOS module — see W-002 (passwordless wheel) and the operator-pubkey constant in `flake.nix`. |
| `sudoMode` | enum `password` \| `passwordless` | `passwordless` for `bob` during the cluster transition (W-002); `password` is the target end state once secrets management lands. |
| `homeManagerProfile` | enum `server` \| `workstation` | Determines which home-manager modules apply. |

**Relationships**:

- An Operator User is defined once and applied to a class of nodes (cluster vs. workstation). The same `bob` user is provisioned on every Cluster Node; `eaglerock` is provisioned on every Workstation Node. The user *definition* is shared; per-host instances are realized at NixOS evaluation time.
- An Operator User uses one **Home-Manager Profile** (server or workstation).
- An Operator User loads one **Shell Environment** (PS1 form + toolbox), which depends on the host class.

---

## Host Storage Layout

The post-provisioning disk layout for a Cluster Node.

**Attributes**:

| Mount | Backing | Filesystem | Notes |
|-------|---------|------------|-------|
| `/boot` | SD card | vfat (firmware) | Required for Pi firmware boot. Contains kernel, initramfs, device tree, U-Boot configuration. |
| `/` | mdadm RAID1 across `usbDevice0` + `usbDevice1` | ext4 | Root filesystem; durable against single USB-drive loss. |
| `/srv/usb` | Same RAID1 array (different LV / partition) | ext4 | Storage path for workloads that want pre-replicated USB-backed storage. |
| `/srv/ssd` | NVMe (`nvmeDevice`) | xfs | Pi 5 only. Mount-point absent on Pi 4 nodes. |

**Recovery layout** (when USB drives are absent or RAID1 is degraded beyond mount):

| Mount | Backing | Filesystem | Notes |
|-------|---------|------------|-------|
| `/boot` | SD card | vfat | Firmware boot. |
| `/` | SD card root partition | ext4 | The SD bootstrap image's own root. Contains the recovery utility set from `modules/sd/recovery-utils.nix`. |

**State transitions**:

`unformatted USB` + `unformatted NVMe` → (nixos-anywhere + disko run) → `RAID1 + NVMe formatted` → (reboot) → `live mounts as above`.

A re-run of nixos-anywhere on a `live mounts` node MUST be either idempotent (no-op disko) or refuse with a clear message (FR-013). The disko schemas use `--mode disko` rather than `--mode disko-destroy` by default to enforce this.

---

## NixOS Configuration

The per-host NixOS module composition.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `imports` | list[Path] | Cluster scope (`modules/cluster/common.nix`, `modules/cluster/hlc/*`), device scope (`modules/hardware/rpi{4,5}.nix`), shell scope (`modules/shell/*`), users (`modules/users/operator.nix`), and the per-host file. |
| `networking.hostName` | string | Short hostname; matches the `hostname` field on the Cluster Node entity. |
| `networking.domain` | string | `marks.dev` for HLC. |
| `disko.devices` | reference | Pulled from `disko/rpi{4,5}.nix` keyed by family. |

**Invariants**:

- Per-host file MUST contain only what is genuinely host-specific (FR-005, FR-008). Hostname, IP/MAC if not DHCP-managed, USB device IDs, NVMe device ID, and any per-host overrides.
- Adding a new host MUST require at most 2 file changes (FR-008, SC-003): the new `hosts/<hostname>/configuration.nix` and the `flake.nix` `nixosConfigurations` entry.

---

## Disko Schema

The declarative disk layout for `nixos-anywhere`.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `family` | enum `rpi4` \| `rpi5` | Selects schema. |
| `usbDevice0` / `usbDevice1` | by-id path | RAID1 members. |
| `nvmeDevice` | by-id path \| null | Pi 5 only. |
| `mode` | enum `disko` \| `disko-destroy` | Default `disko` (idempotent). `disko-destroy` reserved for explicit re-provision. |

**Output contract**: After execution, the partitions and filesystems described in **Host Storage Layout** above are present and mounted; `nixos-anywhere` then proceeds to install the per-host NixOS configuration onto them.

---

## Sysadmin Toolbox

The shared package set installed on every NixOS host (cluster and workstation).

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `packages` | list[(name, comment)] | Alphabetically sorted; each package carries an inline comment describing its purpose (FR-015, Constitution Principle VI). |

**Invariants**:

- The toolbox module is the sole source of these packages across the fleet (FR-015).
- The same toolbox is loaded on `silicon` (workstation) and on every cluster node — operator UX consistency (SC-006).
- Any addition is alphabetically inserted with a one-line rationale comment; no silent additions.

---

## MOTD

A NixOS module that renders a per-host MOTD on SSH login.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `banner` | multi-line string | Static ASCII art; HLC value matches the post-mortem reference exactly (FR-018). |
| `quote` | string | "Let's build just a happy little cloud." — ~ Bob Ross. |
| `hostnameFormat` | string | `Cluster node: <fqdn>`; FQDN interpolated from `config.networking.fqdn`. |

**Relationships**:

- One **Cluster Node** has one MOTD (parameterized; HLC nodes get the HLC banner; future ecto-1 nodes would override).

---

## Shell Environment

The interactive shell configuration for a session.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `shell` | enum `bash` | Bash only; zsh out of scope (FR-016). |
| `ps1Form` | enum `local` \| `remote` | Selected at session-start time by examining `$SSH_CONNECTION`. |
| `ps1Glyphs` | string | `☁⛰☁` (with `︎` text-presentation selector after `⛰`). |
| `ps1Color` | bool | True for local; false for remote (R-002, R-003 in spec clarifications). |

**Relationships**:

- One **Operator User** has one Shell Environment.
- The shell module composes the **Sysadmin Toolbox**.

---

## Build Artifact

What `make build-image`, `make build`, and `make provision` produce.

**Attributes**:

| Field | Type | Notes |
|-------|------|-------|
| `kind` | enum `sdImage` \| `toplevel` \| `provisioned` | What the build target produces. |
| `host` | string | Target host. |
| `path` | Nix store path | The realized build output. |
| `cacheable` | bool | True; rebuilt only when input closure hash changes. |
| `rebuildFlag` | bool | `REBUILD=1` make flag forces re-realization regardless of cache. |

**Invariants**:

- Default behavior (no `REBUILD` flag) MUST not produce a stale image (FR-004, R-006). Achieved by ensuring the SD-image derivation closure correctly depends on the SD bootstrap source.
- Build commands route through Makefile targets (Constitution VII) for any agent-driven invocation.

---

## Workarounds Ledger Entry

Each open deviation from the constitution is tracked in `specs/WORKAROUNDS.md`. Currently W-001 (inline host configs), W-002 (passwordless wheel), W-003 (`PasswordAuthentication = true`).

**Attributes**: as defined in `specs/WORKAROUNDS.md` (title, sites, deviates from, reason, exit condition, target phase, opened, resolved).

**Relationships**:

- Each Ledger Entry references one or more **NixOS Configuration** sites.
- Each Ledger Entry has a target phase that closes it.

---

## Out-of-band entities (referenced, not modeled)

- **k3s cluster state** — out of scope for this spec; will be modeled by the follow-on cluster-bootstrap spec.
- **Longhorn / ArgoCD / workload manifests** — out of scope; live in a separate repo.
- **Existing Debian cluster on `hlc-301..308`** — pre-existing, untouched by this spec; allowed to degrade as `hlc-401` migrates to NixOS.
- **Network infrastructure** (Unifi, PiHole, DHCP) — pre-existing assumptions, not modeled here.
