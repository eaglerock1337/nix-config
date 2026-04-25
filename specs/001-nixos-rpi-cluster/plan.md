# Implementation Plan: NixOS RPi Cluster Foundation

**Branch**: `001-nixos-rpi-cluster` | **Date**: 2026-04-25 | **Spec**: `specs/001-nixos-rpi-cluster/spec.md`
**Input**: Feature specification from `specs/001-nixos-rpi-cluster/spec.md`

## Summary

Build a modular, reproducible NixOS configuration for a 12-node Raspberry Pi k3s cluster
(4× Pi4 control plane + 8× Pi5 workers) with shared modules for users, shell environment,
MOTD, storage, and secrets — all declarative and extensible for future hosts and clusters.

The implementation is **prioritized to get nodes online and syncable first** — shared
modules, flake wiring, and host configs come before k3s, storage, and GitOps layers.

## Technical Context

**Language/Version**: Nix (NixOS 25.11 stable, flakes)
**Primary Dependencies**: nixpkgs 25.11, home-manager 25.11, raspberry-pi-nix, nixos-hardware, sops-nix, disko
**Storage**: disko-managed mdadm RAID1 (2× 64GB USB 3.2 per node, both Pi4 and Pi5) + SD card boot; NVMe 1TB (Pi5 workers only) for Longhorn PVs
**Testing**: `nixos-rebuild dry-run --flake .#<host>` for all hosts; `build-vm` for boot/hardware changes
**Target Platform**: aarch64-linux (Raspberry Pi 4 + 5)
**Project Type**: NixOS configuration repository (declarative infrastructure)
**Performance Goals**: N/A — build-time is bounded by cross-compilation speed on gibson
**Constraints**: All config declarative (Constitution Principle I); no imperative provisioning steps beyond SD flash + nixos-anywhere; all secrets encrypted at rest
**Scale/Scope**: 12 cluster nodes + 1 existing desktop host (silicon); extensible to ecto-1 cluster and future desktops

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | All node config is Nix modules; no imperative state |
| II. Reproducibility via Flakes | ✅ PASS | All deps in flake.lock; new inputs (sops-nix, disko) will be added to flake.nix |
| III. Modular Design | ✅ PASS | One concern per module: k3s, disko, users, MOTD, shell, hardware per board |
| IV. Safety-First Changes | ✅ PASS | dry-run gate in Makefile; build-vm for boot/hardware modules |
| V. Minimal & Explicit Footprint | ✅ PASS | No speculative modules; ecto-1 stubs are explicitly required by spec |

**Post-Phase 1 re-check**: All principles remain satisfied. Module separation is clean.
No new unfree packages required. Longhorn risk (R-006) is mitigated by starting with
local-path provisioner — no speculative complexity.

## Project Structure

### Documentation (this feature)

```text
specs/001-nixos-rpi-cluster/
├── plan.md              # This file
├── research.md          # Phase 0 output (complete)
├── data-model.md        # Phase 1 output (complete)
├── quickstart.md        # Phase 1 output (complete)
└── tasks.md             # Phase 2 output (pending /speckit-tasks)
```

### Source Code (repository root)

```text
flake.nix                           # Entry point — add sops-nix, disko inputs; 12 new nixosConfigurations
hosts/
├── silicon/                        # Existing desktop (untouched)
├── hlc-401/                        # Control plane init server
│   └── configuration.nix           # Thin config: imports shared modules, sets hostname/IP/role
├── hlc-402/                        # Control plane server
│   └── configuration.nix
├── hlc-403/
│   └── configuration.nix
├── hlc-404/
│   └── configuration.nix
├── hlc-501/                        # Worker node (existing, refactored to use shared modules)
│   └── configuration.nix
├── hlc-50{2..8}/                   # Worker nodes
│   └── configuration.nix
modules/
├── hardware/
│   ├── x1-carbon.nix               # Existing
│   ├── rpi4.nix                    # Pi4 board config (bcm2711, cgroup params, firmware)
│   └── rpi5.nix                    # Pi5 board config (bcm2712, cgroup params, NVMe detection)
├── hosts/
│   ├── common.nix                  # Existing
│   ├── desktop-ui.nix              # Existing
│   └── gaming.nix                  # Existing
├── cluster/
│   ├── hlc/
│   │   ├── default.nix             # HLC cluster defaults: node registry, network config
│   │   ├── motd.nix                # HLC-specific ASCII art + Bob Ross quote
│   │   └── node.nix                # Per-node config options (hostname, IP, role)
│   └── ecto1/
│       └── default.nix             # Stub: placeholder MOTD, slimer user
├── k8s/
│   ├── k3s-server.nix              # k3s server role module (etcd, clusterInit, serverAddr)
│   ├── k3s-agent.nix               # k3s agent role module (serverAddr, token)
│   ├── k3s-common.nix              # Shared k3s config (firewall, cgroup, tokenFile)
│   └── longhorn-prereqs.nix        # Host prerequisites for Longhorn (open-iscsi, kernel modules)
├── storage/
│   ├── disko-rpi4.nix              # disko config: SD boot + USB RAID1
│   └── disko-rpi5.nix              # disko config: SD boot + USB RAID1 + NVMe passthrough
├── users/
│   └── operator.nix                # Parameterized user module (username, SSH keys, groups)
├── shell/
│   ├── common.nix                  # Shared shell env: PS1 prompt, bash config, aliases
│   ├── utilities.nix               # Curated sysadmin tools + syshelp script
│   └── prompt.nix                  # PS1 prompt configuration (hostname-aware, role-colored)
└── motd/
    └── default.nix                 # Parameterized MOTD module (clusterName, asciiArt, tagline)

secrets/
├── hlc.yaml                        # sops-encrypted k3s token (all 12 nodes + admin as recipients)
.sops.yaml                          # sops creation rules and age key recipients

home/
├── eaglerock.nix                   # Existing desktop user
└── bob.nix                         # HLC cluster user home-manager config

Makefile                            # Build/provision/update targets
```

**Structure Decision**: Extends the existing `hosts/` + `modules/` hierarchy with new
module directories for `cluster/`, `k8s/`, `storage/`, `users/`, `shell/`, and `motd/`.
Each directory handles one concern. Host configs are thin — they import modules and set
host-specific values only.

## Implementation Phases (Priority Order)

The phases are ordered to **get nodes online and syncable as fast as possible**. Phase A
produces configs that can `nixos-rebuild switch` on live Pis. Everything else builds on top.

### Phase A: Foundation — Get Nodes Online (P0)

**Goal**: Shared modules + flake wiring so all 12 hosts evaluate and can be deployed.

1. **Hardware modules** (`modules/hardware/rpi4.nix`, `rpi5.nix`)
   - Board config (bcm2711/bcm2712), cgroup kernel params, firmware
   - Import `raspberry-pi-nix` board setting per model

2. **Parameterized user module** (`modules/users/operator.nix`)
   - Options: `username`, `sshKeys`, `extraGroups`
   - Wires `users.users.${username}` and `security.sudo`
   - Default: `bob` for HLC, `eaglerock` for desktop, `slimer` for ecto-1

3. **Shell environment** (`modules/shell/common.nix`, `prompt.nix`, `utilities.nix`)
   - **PS1 prompt** (`prompt.nix`): hostname-aware, role-colored prompt
     - Format: `[user@hostname:~/path]$ ` with colors per system class
     - HLC nodes: green hostname (server) or cyan (worker)
     - Desktop: default gruvbox yellow
     - Shows git branch in repos (via bash prompt integration)
   - **Common shell config** (`common.nix`): bash defaults, history, inputrc
   - **Utilities** (`utilities.nix`): curated tool list + `syshelp` command

4. **MOTD module** (`modules/motd/default.nix`)
   - Parameterized: clusterName, asciiArt, tagline, attribution
   - HLC-specific values in `modules/cluster/hlc/motd.nix`

5. **Flake wiring**: Add all 12 `nixosConfigurations` to `flake.nix`
   - Pass shared `specialArgs` (inputs, cluster node registry)
   - Each host imports: hardware module + user module + shell + MOTD + host-specific config

6. **Host configs** (`hosts/hlc-{401..404,501..508}/configuration.nix`)
   - Thin files: import shared modules, set hostname, IP, role
   - Refactor existing `hlc-501` to use shared modules

7. **Validate**: `nixos-rebuild dry-run --flake .#hlc-XXX` passes for all 12 hosts

**Exit criteria**: All 12 hosts evaluate cleanly. An operator can `nixos-rebuild switch`
on a live Pi running the SD card image and get a working NixOS system with SSH, correct
user, PS1 prompt, MOTD, and shell tools.

### Phase B: Storage & Provisioning (P1)

**Goal**: disko configs and nixos-anywhere workflow for unattended provisioning.

1. **Add disko + sops-nix flake inputs**
2. **disko configs** (`modules/storage/disko-rpi4.nix`, `disko-rpi5.nix`)
   - SD card FAT32 `/boot` + USB RAID1 ext4 `/`
   - Pi5 variant leaves NVMe unpartitioned for Longhorn
   - Use `/dev/disk/by-id/` paths for stability
3. **sops-nix integration** (`secrets/hlc.yaml`, `.sops.yaml`)
   - Admin age key generation instructions
   - Host key collection after SD card first-boot
4. **SD card image targets** in Makefile
   - `make build-image-rpi4`, `make build-image-rpi5`
   - `make flash-image HOST=hlc-401 DEV=/dev/sdX`
5. **Provision target**: `make provision HOST=hlc-401 IP=10.23.50.41`
   - Wraps nixos-anywhere with kexec image

**Exit criteria**: Operator can flash SD, boot Pi, run `make provision`, and get a
RAID1-backed NixOS node with encrypted secrets.

### Phase C: k3s Cluster (P2)

**Goal**: k3s modules and cluster bring-up.

1. **k3s modules** (`modules/k8s/k3s-common.nix`, `k3s-server.nix`, `k3s-agent.nix`)
   - Common: firewall ports, tokenFile path, cgroup verification
   - Server: `clusterInit` (hlc-401 only), `serverAddr`, embedded etcd
   - Agent: `serverAddr`, token, kubelet config
2. **Longhorn prerequisites** (`modules/k8s/longhorn-prereqs.nix`)
   - open-iscsi, kernel modules, NVMe readiness check
   - Actual Longhorn deployment deferred to ArgoCD/GitOps phase
3. **Host config updates**: Import k3s role modules per node
4. **Cluster node registry**: Nix attrset mapping hostnames to IPs/roles for serverAddr resolution
5. **Makefile targets**: `make update-node HOST=hlc-401`, `make update-cluster`

**Exit criteria**: `kubectl get nodes` shows all 12 nodes Ready.

### Phase D: GitOps & Day-2 (P3)

**Goal**: ArgoCD bootstrap and rolling update workflow.

1. **ArgoCD bootstrap manifest** (one-time kubectl apply)
2. **App-of-apps pattern** for Longhorn, cert-manager, ingress
3. **Rolling update target**: `make update-cluster` with quorum safety
4. **Migration runbook**: DNS cutover, DHCP, Unifi switch config

### Phase E: Extensibility Stubs (P3)

**Goal**: Validate module structure works for non-HLC hosts.

1. **ecto-1 stub** (`modules/cluster/ecto1/default.nix`)
   - User `slimer`, generic MOTD, placeholder config
2. **Verify silicon unchanged**: Existing desktop config still builds
3. **Document adding a new host** in quickstart.md

## PS1 Prompt Design

The shell prompt is a first-class deliverable. Design:

```bash
# HLC server node (green hostname):
[bob@hlc-401:~/k3s]$

# HLC worker node (cyan hostname):
[bob@hlc-501:~/apps]$

# Desktop (gruvbox yellow hostname):
[eaglerock@silicon:~/git/nix-config]$

# With git branch (all systems):
[bob@hlc-401:~/git/nix-config (main)]$
```

**Implementation** (`modules/shell/prompt.nix`):
- NixOS module option `shell.prompt.hostColor` (per system class)
- Uses `\[\033[...]` ANSI escapes in `programs.bash.promptInit`
- Git branch via `__git_ps1` from `git` package (already available)
- Non-root: `$` suffix; root: `#` suffix
- Exit code indicator: red prompt on non-zero last exit

## Complexity Tracking

No constitution violations. All complexity is directly required by the spec.

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| raspberry-pi-nix archived | HIGH | Pin to known-good commit; evaluate saronic-technologies/rpi-nix fork if broken on 25.11 |
| Longhorn NixOS incompatibility | HIGH | Start with k3s local-path provisioner; evaluate OpenEBS as alternative |
| USB device path instability | MEDIUM | Use `/dev/disk/by-id/` in disko configs |
| Cross-compilation speed | LOW | Use provisioned Pi as remote aarch64 builder after first node |
| QEMU aarch64 emulation failures | MEDIUM | Enable `boot.binfmt.emulatedSystems` on gibson; fallback to native Pi build |
