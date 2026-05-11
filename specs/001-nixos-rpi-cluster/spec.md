# Feature Specification: NixOS RPi Cluster Foundation (v2)

**Feature Branch**: `001-nixos-rpi-cluster`
**Created**: 2026-04-29
**Status**: Draft (rewritten post-mortem)
**Input**: Restart from scratch per `post-mortem-26-04-29.md`. Goal: bring 9 Raspberry Pis (hlc-401 + hlc-501..508) onto NixOS using the actively maintained `nvmd` fork of `nixos-raspberrypi`, with a layered module structure, full-disk provisioning via `nixos-anywhere`/`disko`, operator UX (MOTD, PS1, sysadmin toolbox, home-manager), and k3s prerequisites installed. Cluster bootstrap, joining, and ArgoCD/workload management are out of scope.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Boot a Raspberry Pi 5 on NixOS from a Barebones SD Card (Priority: P1)

The operator (running on `gibson`) builds a minimal SD-card image from this repo, flashes it onto a Raspberry Pi 5 (initial target: `hlc-501`), inserts the card, powers the Pi on, and confirms the node boots into NixOS, joins the network, and accepts SSH from operator's key as user `bob`. The image uses the `nvmd` fork of `nixos-raspberrypi` and contains only the minimum needed to reach this point: bob user with authorized SSH key, network configuration, and basic recovery utilities.

**Why this priority**: This is the foundation. Without a reproducible "Pi boots and is reachable" baseline on the supported upstream, every later phase is blocked. The post-mortem traced the prior incident to using an archived upstream and a broken `make` step that hid stale images; this story exists to lock in a verified baseline before doing anything else.

**Independent Test**: Operator runs `make flash-image` for `hlc-501`, inserts the SD card, powers on the Pi, and runs `make smoke-test` (or equivalent reachability check) from gibson. Test passes when SSH as `bob@hlc-501` succeeds with operator key and `uname -a` reports NixOS aarch64.

**Acceptance Scenarios**:

1. **Given** a clean repo checkout on gibson and a blank MicroSD card, **When** operator runs the SD image build + flash workflow for `hlc-501`, **Then** flashing produces a bootable SD without manual editing of build outputs.
2. **Given** a flashed SD card, **When** operator inserts it into `hlc-501` and powers the Pi, **Then** the Pi boots, obtains an IP, and accepts SSH for `bob` using operator's key within 5 minutes of power-on.
3. **Given** a configuration change to the SD image source, **When** operator rebuilds the image, **Then** the resulting image reflects the change (no stale-cache bug; documented rebuild flag is the supported path).
4. **Given** the SD-only environment (no USB or NVMe attached), **When** operator boots the Pi, **Then** the Pi reaches a usable login state with recovery utilities (`mdadm`, `parted`, `lsblk`, basic editor) available.

---

### User Story 2 — Modular Per-Host Configuration for All 9 Nodes Across Both Pi Generations (Priority: P2)

The operator can build (`nixos-rebuild dry-run --flake .#<host>`) a NixOS configuration for any of the 9 in-scope nodes (`hlc-401` on Pi 4; `hlc-501..508` on Pi 5) from a single repo. Configuration is layered so that node files contain only what is genuinely node-specific; everything reusable lives in shared modules: cluster scope (HLC), device scope (rpi4 vs rpi5), and operator-environment scope (server-bash, server-tooling, home-manager). The SD bootstrap configuration is kept separate from the full per-host configuration.

**Why this priority**: The previous attempt collapsed because a single host's configuration mixed concerns; debugging touched files that should not have been part of bootstrap. Splitting layers up front prevents recurrence and makes per-Pi-family hardware support tractable.

**Independent Test**: From a clean checkout, `nixos-rebuild dry-run --flake .#<host>` succeeds for each of the 9 in-scope hosts. Adding a new host file under `hosts/<hostname>/` plus a flake entry is sufficient for it to evaluate; no edits to existing per-host configurations or shared modules are required.

**Acceptance Scenarios**:

1. **Given** the layered repo, **When** operator runs `nixos-rebuild dry-run --flake .#hlc-501`, **Then** evaluation succeeds.
2. **Given** the same repo, **When** operator runs the equivalent dry-run for `hlc-401` (Pi 4), **Then** evaluation succeeds and pulls in Pi 4-specific hardware configuration distinct from Pi 5.
3. **Given** a new node `hlc-502`, **When** operator adds a thin host config plus flake entry, **Then** dry-run for the new host succeeds with no edits to other hosts or to shared modules.
4. **Given** the SD bootstrap config, **When** operator builds it, **Then** it does **not** pull in full per-host service configuration (such as k3s prerequisites or full operator toolbox).

---

### User Story 3 — Full-Disk Provisioning with USB RAID Root and NVMe Data Volume (Priority: P3)

After a node is reachable on the SD baseline, the operator runs `nixos-anywhere` (from gibson or on the node itself) to install the full per-host NixOS configuration onto persistent storage. The result: `/boot` remains on the SD card; `/` lives on a 2-disk USB-3 mdadm RAID1 mirror (single partition, full ~28.6 GiB array); on Pi 5 nodes, `/srv` is mounted from a 1 TB NVMe drive. The Pi prefers booting from the USB array when present and falls back to the SD-card live environment for recovery if the USB array is unavailable.

**Why this priority**: This is the durable runtime configuration the cluster needs. The SD-only baseline (Story 1) is provisioning scaffolding; without USB-backed root and NVMe data volume, the nodes cannot host real workloads.

**Independent Test**: For a representative Pi 5 node and the Pi 4 node (`hlc-401`), the operator runs the documented `nixos-anywhere` workflow against the SD-baseline node and, after reboot, confirms: `/` is on the mdadm array and `/srv` is the NVMe (Pi 5 only), and removing the USB drives + rebooting brings the Pi back into the SD-card recovery environment with `mdadm` available to inspect the array.

**Acceptance Scenarios**:

1. **Given** a Pi 5 node booted on the SD baseline with two USB drives and an NVMe attached, **When** operator runs the provisioning workflow, **Then** the node reboots into NixOS with `/` on the mdadm RAID1 mirror and `/srv` mounted from the NVMe.
2. **Given** a provisioned Pi 5 node, **When** the USB array is healthy, **Then** the system boots from the USB array and the SD card is used only for `/boot`.
3. **Given** a provisioned node with the USB drives physically removed, **When** the operator powers the Pi on, **Then** the Pi falls back to the SD-card recovery environment and exposes `mdadm` and other utilities for repair.
4. **Given** the Pi 4 node `hlc-401` (no NVMe), **When** the same workflow runs, **Then** the node provisions with `/` on USB RAID1; `/srv` is absent without error.
5. **Given** the operator runs the provisioning workflow against an already-provisioned node, **When** they re-run the same target, **Then** the operation is either idempotent or fails with a clear, documented message — never silently corrupts the array.

---

### User Story 4 — Consistent Operator Shell Environment Across All Managed Systems (Priority: P4)

When the operator SSHes into any managed NixOS system (silicon today; the 9 cluster nodes after this spec), they land in a familiar bash environment: a styled PS1 that distinguishes local-vs-remote sessions, a curated sysadmin toolbox identical across systems, sensible home-manager defaults (e.g., neovim) shared with workstations where appropriate, and on cluster nodes a dynamic MOTD showing the HLC ASCII banner, the node hostname, and the Bob Ross quote. The toolbox lives in its own module included on every NixOS host (cluster nodes and silicon); each package carries a one-line comment describing its purpose.

**Why this priority**: Consistent operator UX across nodes reduces cognitive load and incident time. The previous attempt's PS1 fight contributed to debugging confusion; doing this once, in one shared module, with parameterization for "remote vs. local" and "server vs. workstation," prevents recurrence.

**Independent Test**: Operator SSHes as `bob@hlc-501` and observes: HLC MOTD with hostname `hlc-501.marks.dev`, styled PS1, all toolbox commands resolvable on `$PATH`. Operator SSHes as `eaglerock@silicon` and observes: same toolbox commands resolvable, no HLC MOTD, workstation-specific home-manager defaults preserved.

**Acceptance Scenarios**:

1. **Given** an SSH session into any cluster node as `bob`, **When** the session opens, **Then** the MOTD shown matches the post-mortem reference (HLC ASCII banner, `Cluster node: <fqdn>`, Bob Ross quote) with hostname interpolated dynamically.
2. **Given** an SSH session into any managed system, **When** the operator runs each tool in the documented toolbox, **Then** every tool resolves and runs.
3. **Given** a local terminal on silicon and a remote SSH session, **When** the operator inspects the prompt, **Then** the PS1 visibly differs to indicate local vs. remote.
4. **Given** server-side users (`bob`) and workstation users (`eaglerock`), **When** their home-manager configurations are evaluated, **Then** shared defaults (e.g., neovim baseline) apply to both, while workstation-only modules (i3, polybar, etc.) apply only to workstations.

---

### User Story 5 — Kubernetes / k3s Prerequisites Installed on Every Node (Priority: P5)

Every in-scope node has the packages and OS-level configuration required to participate in a k3s cluster: k3s itself, container runtime dependencies, `k9s`, a `k` shell alias for `kubectl`, and any kernel/module/sysctl settings k3s needs. **Joining the cluster, electing servers, distributing tokens, and managing workloads are out of scope for this spec** — those are handled in a follow-on spec. The point of this story is that, after this spec ships, no further OS-level work is needed before the next spec can wire k3s into a running cluster.

**Why this priority**: Lower priority than Stories 1–4 because it depends on them, but in scope so that the next spec starts at "configure cluster" rather than "install k3s." Keeping it OS-level only also draws a sharp line: this spec does not need to deal with HA topology, embedded etcd, agent discovery, or Longhorn.

**Independent Test**: On any provisioned node, `k3s --version`, `k9s --version`, and `k version --client` (alias resolving to `kubectl`) all succeed without an active cluster. No k3s service is running and no cluster state exists on the node.

**Acceptance Scenarios**:

1. **Given** a fully provisioned node, **When** the operator queries the package set, **Then** k3s, container runtime dependencies, k9s, and `kubectl` are present.
2. **Given** the same node, **When** the operator inspects systemd, **Then** the k3s service unit is **enabled but stopped** (it will start on next boot once cluster configuration is supplied), with no cluster configuration or token on disk yet, so the follow-on cluster-bootstrap spec only needs to drop config and trigger the start.
3. **Given** the node's kernel/module/sysctl state, **When** the operator inspects k3s prerequisites (cgroups v2, br_netfilter, ip_forward, etc.), **Then** all are configured per upstream k3s requirements.
4. **Given** an interactive shell as `bob`, **When** the operator types `k get nodes`, **Then** the alias resolves to `kubectl get nodes` (the command will return an error since no cluster is configured; that error is expected and correct for this spec).

---

### Edge Cases

- A USB drive in the RAID1 pair fails mid-provision — the install should fail loudly and leave a recoverable state, not a half-written array.
- A Pi 5 NVMe is missing or not detected — the system boots and `/srv` is simply absent (logged), rather than failing.
- `nixos-anywhere` loses SSH partway through — the SD baseline must remain intact so the operator can retry.
- The SD baseline image is rebuilt but the binary cache returns a stale artifact — the documented rebuild path must invalidate the cache (the post-mortem traced multi-day debugging to this exact failure mode).
- Operator SSH key changes — recovery is by reflashing the SD baseline (the SD bootstrap config is the keying root), not by editing a deployed node.
- Pi 4 node has no NVMe — provisioning must succeed with only USB RAID, no Pi 5-specific modules pulled in.
- A node boots from SD recovery (USB drives missing) — operator can run `mdadm` and other recovery tools without re-provisioning.
- USB drives inserted in unexpected order before provisioning — kernel assigns `sda`/`sdb` by insertion order, not physical port. By-path identifiers (`platform-xhci-hcd.0-...` / `platform-xhci-hcd.1-...`) remain port-fixed regardless. Disko MUST use by-path (FR-010a); never reference `sda`/`sdb` directly in the disko schema.
- Existing k3s cluster on Debian Pi 4s loses `hlc-401` when it is rebuilt as NixOS — acceptable per scope (cluster mgmt is out of scope; existing cluster will limp on `hlc-402..404` until the follow-on cutover spec).
- **SD bootstrap `pam_systemd` blocking (W-004)**: `pam_systemd` creates and destroys a D-Bus user session on every SSH connection; on teardown of non-PTY sessions (`ssh host cmd`), D-Bus cleanup blocks sshd from accepting new connections for several minutes. Observed symptom: `make smoke-test` passes but an immediately-following interactive SSH is unreachable until sshd self-recovers. Resolution: `security.pam.services.sshd.startSession = lib.mkForce false` in `modules/sd/bootstrap.nix`. This is bootstrap-scoped and permanent for that module; provisioned (full) per-host configurations retain the default `startSession = true` and are unaffected.

## Requirements *(mandatory)*

### Functional Requirements

#### Upstream and image baseline

- **FR-001**: All RPi NixOS configuration MUST use the `nvmd` fork of `nixos-raspberrypi` (`https://github.com/nvmd/nixos-raspberrypi`) as the upstream source of truth, replacing the archived `nix-community/raspberry-pi-nix` currently on `main`.
- **FR-002**: The repo MUST produce a bootable SD image, built on `gibson`, that boots both Raspberry Pi 4 and Raspberry Pi 5 hardware. The image MUST contain only: `bob` user with operator-supplied authorized SSH key, network configuration sufficient to reach DHCP on the HLC VLAN, and a small set of recovery utilities (`mdadm`, `parted`, `lsblk`, a basic editor, `git`, `curl`).
- **FR-003**: The SD bootstrap configuration MUST be physically separated in the repo from the per-host post-provisioning configuration, so that bootstrapping cannot accidentally pull in (or be broken by) per-host service modules.
- **FR-004**: The image build workflow MUST surface a documented mechanism (e.g. `--rebuild`) for forcing a clean rebuild. Default behavior of `make flash-image` MUST never produce a stale image; if the build cache cannot be safely reused, the build MUST rebuild rather than silently flash an old artifact.

#### Repository structure and per-host configuration

- **FR-005**: The repository MUST be structured in three layered scopes plus per-node configuration. Operator-environment modules (toolbox, PS1, MOTD, home-manager) are *cross-cutting* — they are imported by the cluster scope and apply to all hosts in scope; they are not a fourth layer. The three scopes, in import order from generic to specific, are:
  - generic-server / generic-cluster scope (modules reusable by any future cluster, e.g. ecto-1);
  - HLC-cluster scope (HLC-specific shared configuration);
  - device scope (rpi4 vs. rpi5 hardware modules);
  - per-host scope (`hosts/<hostname>/`) — not a shared scope; contains only what is genuinely node-specific.
- **FR-006**: Top-level per-host `flake.nix` entries MUST include only minimal inclusions (per-host `configuration.nix`, cluster-specific configuration, device-specific configuration); deeper modules MUST be imported from within the appropriate scope-level module rather than enumerated at the host level.
- **FR-007**: Per-host configuration MUST evaluate via `nixos-rebuild dry-run --flake .#<host>` from a clean checkout for all 9 in-scope hosts (`hlc-401`, `hlc-501..508`).
- **FR-008**: Adding a new host to the repo MUST require at most two edits: a new `hosts/<hostname>/` directory and a corresponding `flake.nix` `nixosConfigurations` entry. No edits to existing per-host configurations or shared modules MUST be required.
- **FR-009**: All 12 cluster nodes (`hlc-401..404` Pi 4 control-plane class, `hlc-501..508` Pi 5 worker class) MUST have evaluable per-host configuration in this repo and MUST succeed `nixos-rebuild dry-run --flake .#<host>` from a clean checkout. The 3 deferred Pi 4 nodes (`hlc-402..404`) MUST NOT be physically provisioned in this spec — they exist as configuration only, validating the layered structure at full target scale and leaving the follow-on cutover spec a pure provisioning task.

#### Persistent storage and provisioning

- **FR-010**: After provisioning via `nixos-anywhere`/`disko`, each in-scope node MUST have:
  - `/boot` on the SD card;
  - `/` on a 2-disk USB-3 mdadm RAID1 mirror (full array, single partition; drives are ~30 GB / ~28.6 GiB usable);
  - `/srv` on the 1 TB NVMe (Pi 5 nodes only; Pi 4 nodes do not mount this path and MUST NOT fail because of its absence).
- **FR-010a**: USB RAID disks MUST be identified in disko by `/dev/disk/by-path/` using the non-versioned `platform-xhci-hcd.N-usb-0:1:1.0-scsi-0:0:0:0` pattern, where `N=0` is the left (a) port and `N=1` is the right (b) port. Operator convention: a-drives are always inserted in the left USB port, b-drives in the right USB port, as viewed from the operator's perspective. This convention applies to all Pi 5 nodes; path correctness MUST be validated by confirming both drives show a `usbv3` alias in `/dev/disk/by-path/` before provisioning (a `usbv2` alias indicates the drive negotiated at USB 2.0 speed and the connection should be re-seated).
- **FR-011**: The boot order MUST prefer the USB array when healthy and fall back to the SD-card recovery environment when the USB array is absent or unbootable. Recovery from SD MUST be possible without operator intervention beyond removing/replacing USB drives.
- **FR-012**: The provisioning workflow (`nixos-anywhere` invocation + `disko` schema) MUST be invokable from `gibson` against a SD-baseline node. Operator MAY also invoke it on the node itself; both paths MUST be documented. `nixos-anywhere` MUST connect as `bob`; this requires `bob` to have passwordless sudo on the bootstrap image. No explicit sudo flag is needed on the `nixos-anywhere` invocation — passwordless sudo on the target is sufficient (confirmed 2026-05-05).
- **FR-013**: Provisioning MUST be re-runnable. Re-running on an already-provisioned node MUST either be idempotent or refuse with a documented message; it MUST NOT silently corrupt the existing array or filesystem.
- **FR-014**: Filesystem choices for `/` and `/srv` MUST be selected for their use case (durability for `/`, throughput-friendly for `/srv`) and documented in the plan; this spec does not pin specific filesystems.

#### Operator UX (shell, MOTD, toolbox, home-manager)

- **FR-015**: All NixOS hosts (cluster nodes and `silicon`) MUST share a single sysadmin toolbox module. Each package in the module MUST carry an inline comment describing its purpose; the module MUST be the sole source of these tools across the fleet.
- **FR-016**: Bash MUST be the canonical shell. The bash environment MUST be shared across all NixOS hosts; the styled PS1 MUST visibly differ when the session is local vs. remote (mirroring `silicon`'s existing behavior).
- **FR-017**: A stylized HLC-themed PS1 MUST be defined for cluster nodes. The PS1 MUST take two distinct forms — local and remote — using the Bob Ross-themed glyph sequence `☁⛰☁` (cloud, mountain, cloud) as the HLC motif:
    - **Local form** (no SSH): structurally identical to silicon's existing prompt (single-line, working directory, prompt indicator at the end), but with `☁⛰☁` substituted for silicon's `////` indicator. Silicon's existing color treatment (Gruvbox path color, root vs. user coloring, etc.) MUST be preserved on cluster nodes when running locally; the operator's local terminal is not subject to xterm-only constraints. Concretely: `\w ☁⛰☁ ` with the same color escapes silicon uses today.
    - **Remote form** (SSH session): two-line, box-drawing prompt of the form
      ```
      ┌─╸<user>@<fqdn> ☁⛰☁ [<cwd>]
      └──╸$
      ```
      where `<fqdn>` is the fully qualified hostname (e.g. `bob@hlc-501.marks.dev`) and `<cwd>` appears in square brackets. The remote form MUST NOT rely on terminal color escapes (no `\033[...m` color codes); plain `TERM=xterm` SSH connections MUST render it correctly. Bold (`\e[1m`) MAY be used on glyphs; nothing else.
    - The mountain glyph (`⛰`, U+26F0) defaults to emoji presentation in some terminals; the implementation MUST select a presentation strategy (variation selector `U+FE0E` for text presentation, fallback ASCII, or accepted emoji rendering) and document the choice.
- **FR-018**: Each cluster node MUST display a per-host MOTD on SSH login matching the exact text in `post-mortem-26-04-29.md` (HLC ASCII banner, `Cluster node: <fqdn>`, Bob Ross quote). The hostname MUST be interpolated dynamically from `config.networking.fqdn`; the banner and quote are static. The MOTD MUST be implemented as a parameterized NixOS module so future clusters can override the banner.
- **FR-019**: Home-manager configuration MUST be modularized so that cross-cutting defaults (e.g., neovim, git, basic dotfiles) are shared between server users (`bob`) and workstation users (`eaglerock`), while workstation-only modules (i3, polybar, etc.) remain workstation-only.
- **FR-020**: All cluster nodes MUST be reachable via SSH as `bob` using the operator's SSH key. Password authentication MUST be off post-provisioning. For this spec, `bob`'s authorized key MAY be hard-coded in a NixOS module; secrets management (e.g., `sops-nix`) is out of scope.

#### Kubernetes prerequisites

- **FR-021**: Each in-scope node MUST have k3s, container runtime dependencies, `k9s`, and a `k` alias for `kubectl` installed at the OS level.
- **FR-022**: Kernel modules and sysctl settings required by k3s (per upstream documentation) MUST be enabled on every in-scope node.
- **FR-023**: This spec MUST NOT join, configure, or run a k3s cluster. Cluster bootstrap, server election, agent discovery, token distribution, and workload management are explicitly the scope of a follow-on spec.

#### Operator workflow (Makefile / equivalent)

- **FR-024**: The operator workflow MUST expose, at minimum, the following Makefile (or equivalent) targets by end of spec. Each target is added in the phase that first needs it (just-in-time, not pre-built); the set below is the end-of-spec total, not the Phase 0 starting state:
  - `build-image HOST=<host>` (with `REBUILD=1` flag added Phase 3) — SD image build with explicit cache-bust.
  - `flash-image HOST=<host> DEV=<dev>` — write SD image to physical device.
  - `silicon-dry`, `silicon-switch` — silicon-specific dry-run / switch (workstation).
  - `update` — `nix flake update`.
  - `dry-run HOST=<host>` — single-host closure evaluation (gibson uses `nix build --dry-run`; silicon uses `nixos-rebuild dry-run`).
  - `build HOST=<host>` — full single-host toplevel build.
  - `smoke-test HOST=<host>` — single-node reachability check: remove SSH host key from `~/.ssh/known_hosts` for both the node IP and hostname (prevent stale-key failures on reflash), then verify IP reachability via `ping -c 1 -W 3 <IP>`, then verify non-PTY SSH login succeeds on the hostname (no `-t` flag; PTY mode caused Pi login hangs during testing; plain `ssh` with a simple command such as `uname -a` is the correct form).
  - `ip HOST=<host>` — derive a node's IP from its hostname per the HLC IP convention.
  - `provision HOST=<host>` — `nixos-anywhere` wrapper for the first install of a node onto USB-RAID + NVMe.
  - `update-node HOST=<host>` — single-node `nixos-rebuild switch --target-host` for post-provisioning configuration updates.
  - `rollback HOST=<host>` — single-node `nixos-rebuild --rollback --target-host`.

  `IP=<ip>` parameters on host-targeting targets MUST be optional, derived from `HOST` per the HLC IP convention; an explicit override is accepted for non-standard situations. SSH-login convenience targets are out of scope; operators connect via `ssh bob@<hostname>`. Cluster-operations automation (automated single-command canary, cluster-wide rolling deploys, `encrypt-secret` integration) is **out of scope for this spec** — see Out of Scope below.

#### Debug skill (`/speckit-debug`)

- **FR-028**: A `/speckit-debug` Claude Code skill MUST exist for this project at `.claude/skills/speckit-debug/skill.md`. Its behavior is governed by the following rules, derived from the post-mortem and cluster constraints:
  1. **Operator-initiated**: The skill starts from the operator's description of the issue. No automatic context pre-loading occurs at invocation.
  2. **Network-only**: All diagnostic steps MUST be achievable headlessly over SSH from gibson. The skill MUST NOT suggest any step requiring physical access (HDMI, serial console, keyboard, power cycling without operator confirmation). Cluster nodes are permanently headless; this is a hard constraint with no exceptions. Where a Makefile target exists for a diagnostic action, the skill MUST prefer it over raw CLI invocation (Constitution §VII).
  3. **Operator-trust model**: Operator observations are the primary source of truth. If the skill's reasoning conflicts with what the operator reports, the skill MUST surface the disagreement for discussion — it MUST NOT silently adopt a different hypothesis or dismiss the operator's observation. Operators can be mistaken; when the skill suspects an error it asks, it does not assume.
  4. **Conversational format**: The skill conducts an unstructured conversational debug session. No fixed output template is required.
  5. **Context**: At invocation the skill reads the project constitution and `specs/001-nixos-rpi-cluster/post-mortem-26-04-29.md` to internalize the cluster constraints and operator-collaboration rules. The spec and plan are read on demand if the issue requires them. If either file is unreadable at invocation, the skill MUST warn the operator and proceed in degraded mode using its embedded principles rather than failing silently.

#### Hardware and firmware

- **FR-025**: Each cluster node's `config.txt` MUST be set declaratively (via the upstream NixOS module surface, not by hand-editing the FAT partition) to a headless-server profile: `gpu_mem=16`, `dtparam=audio=off`, `dtoverlay=disable-bt`, `disable_splash=1`, `boot_delay=0`, plus Pi 5 NVMe enablement (`dtparam=nvme`) and any per-family thermal/overclock settings selected per [research.md R-011 / R-012](./research.md). Per-host `config.txt` overrides are permitted only for items genuinely host-specific.
- **FR-026**: Each cluster node's EEPROM firmware MUST be brought to a known revision and configured declaratively during the SD baseline boot via a NixOS one-shot service. Configuration MUST include `BOOT_ORDER = 0xf14` (USB-first, SD-fallback per FR-011) and the Pi-family-specific options enumerated in [research.md R-013](./research.md). The service MUST be idempotent (subsequent boots no-op).
- **FR-027**: Cooling configuration MUST match the installed hardware — passive heatsink on Pi 4 (modest overclock, conservative), official heatsink+fan on Pi 5 (stock clocks, kernel-controlled fan curve). Specific frequencies and overvoltage values per [research.md R-012](./research.md). No node MUST be overclocked beyond the validated profile for its installed cooler.

### Key Entities

- **Cluster node**: A physical Pi with hostname (`hlc-401`, `hlc-501..508`), Pi family (rpi4 or rpi5), IP, MAC, role tag.
- **SD bootstrap image**: A bootable SD-card image whose only purpose is to bring a Pi to a reachable state for `nixos-anywhere` and to serve as a recovery environment if the USB array fails.
- **Per-host NixOS configuration**: The full configuration applied after provisioning; lives at `hosts/<hostname>/` and pulls from cluster, device, and operator-environment scopes.
- **USB RAID pair**: Two ~30 GB USB-3 drives (~28.6 GiB usable) configured as mdadm RAID1; single partition for root filesystem.
- **NVMe volume**: 1 TB NVMe per Pi 5; mounted at `/srv`.
- **Toolbox module**: Single shared NixOS module installing the operator's CLI utility set across all NixOS hosts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Starting from a clean repo checkout on gibson, the operator can take a Pi 5 from "blank SD card" to "SSH-reachable on HLC VLAN" in under 30 minutes of operator wall-clock time (excluding raw flash time).
- **SC-002**: All 12 cluster hosts (`hlc-401..404`, `hlc-501..508`) succeed `nixos-rebuild dry-run --flake .#<host>` from a clean checkout with no manual edits, even though only the 9 in-scope hosts (`hlc-401`, `hlc-501..508`) are physically provisioned by this spec.
- **SC-003**: Adding a new in-scope host requires no more than 2 file changes (new `hosts/<hostname>/` directory plus a flake entry).
- **SC-004**: Both Pi 4 (`hlc-401`) and Pi 5 (`hlc-501..508`) hardware boot and provision with the same operator workflow; the Pi family is selected by per-host configuration, not by switching tools.
- **SC-005**: A provisioned node whose USB drives are removed boots from the SD recovery environment with `mdadm` and other recovery tools available, without operator intervention beyond a power cycle.
- **SC-006**: An SSH login as `bob` to any cluster node lands in a styled bash session with the HLC MOTD and the full toolbox on `$PATH`. An SSH login as `eaglerock@silicon` lands in the same toolbox without the HLC MOTD.
- **SC-007**: On every in-scope node, `k3s --version`, `k9s --version`, and `k version --client` succeed; the system has all kernel/sysctl prerequisites k3s requires; no cluster state exists.
- **SC-008**: The image build workflow does not produce a stale image: a configuration change to the SD bootstrap source is reflected in the next flashed card without the operator needing to debug a caching layer.

## Assumptions

- Either `gibson` (Ryzen desktop, nix daemon) or `silicon` (ThinkPad X1 Carbon, NixOS) may be used as the build host for aarch64 cross-compilation and SD image builds. Both require the `nixos-raspberrypi.cachix.org` binary cache configured as a substituter and `aarch64-linux` binfmt emulation enabled for cache-miss fallback. Makefile targets abstract the host-specific build commands (Constitution VII).
- The HLC VLAN (`10.23.50.0/24`) and Unifi infrastructure (Dream Machine SE, Switch Pro 48, PiHole DNS) are already in place per the network section of the post-mortem; static DHCP reservations and DNS entries for in-scope hosts will be added as needed.
- Hardware is already on hand and physically installed: 1× Raspberry Pi 4 (`hlc-401`), 8× Raspberry Pi 5 (`hlc-501..508`), 2× 32 GB USB-3 drives per node (~28.6 GiB usable; verified 2026-05-05), 1× 1 TB NVMe per Pi 5, official heatsink+fan on Pi 5s, heatsinks on Pi 4s.
- The `nvmd/nixos-raspberrypi` `main` branch is the recommended consumption point per its README; the repo's `develop` branch is consulted for documentation but not pinned.
- The existing Debian k3s cluster on `hlc-301..308` and `hlc-401..404` is allowed to degrade as `hlc-401` is rebuilt onto NixOS; full migration of workloads off the Debian cluster is the responsibility of a follow-on spec.
- The existing `silicon` configuration will be refactored only as needed to share modules with cluster nodes (toolbox, home-manager defaults). Workstation-specific modules (i3, polybar, etc.) remain workstation-only.
- Secrets management beyond hard-coding `bob`'s SSH key in a NixOS module is out of scope; `sops-nix` (or equivalent) is a follow-on concern.
- ecto-1 cluster support is not required as concrete artifacts; the layered repo structure must simply be such that ecto-1 specific configuration could be added later by adding a new cluster scope module, without touching HLC-specific or generic-server-cluster modules.
- Cluster bootstrap, k3s server election, agent discovery, token distribution, ArgoCD, Longhorn, and workload migration are all explicitly out of scope. This spec stops at "9 nodes are running NixOS with k3s prerequisites in place."
- The Constitution's safety rules apply: changes are dry-run before apply; provisioning workflows are tested on a single node before being run against the rest; the operator is the source of truth on what the hardware is doing, and disagreements are investigated, not assumed away.

## Out of Scope

- Joining, configuring, or running a k3s cluster (servers, agents, tokens, embedded etcd, agent discovery).
- ArgoCD, Helm chart deployment, Longhorn, cert-manager, ingress, or any application workload.
- Migration of workloads off the existing Debian cluster, and decommissioning of `hlc-301..308`.
- Provisioning `hlc-402`, `hlc-403`, `hlc-404` onto NixOS (handled in the follow-on cutover spec).
- ecto-1 cluster configuration (only structural readiness is required).
- The `slimer` user (future ecto-1 server operator) is not configured in this spec. The `modules/users/operator.nix` and home-manager modules MUST be parameterizable so `slimer` can be added later without refactor; that is the only requirement on `slimer` here.
- **Cluster-operations automation**: an automated single-command `canary` target (switch + smoke-test + auto-rollback in one invocation), `update-cluster` (rolling cluster-wide deploys), cluster-wide iteration helpers (`dry-run-all`, `smoke-test-all`), Pi-family build aliases (`build-image-rpi4`, `build-image-rpi5`), and `encrypt-secret` (sops-nix integration) are deferred to a future cluster-operations automation spec. Within this spec, the operator manually canaries by running `make update-node` on one host, verifying with `make smoke-test`, then proceeding (or `make rollback` if the smoke-test fails).
- Network/VLAN reorganization (e.g., the planned move from VLAN 1 to VLAN 42 as the primary network).
- Secrets management beyond hard-coded SSH keys in NixOS modules.
- Monitoring/alerting (Prometheus/Grafana) for the cluster or for RAID health.

## Clarifications

### Session 2026-04-29

- Q1: k3s service state on provisioned nodes? → A: Enabled but stopped. Service unit installed and enabled; no cluster configuration or token on disk; follow-on spec drops config and triggers start. Resolved in User Story 5 acceptance scenario 2.
- Q2: Do the deferred Pi 4 nodes (`hlc-402..404`) appear in the repo? → A: Yes, as fully evaluable per-host configurations. All 12 hosts must succeed `nixos-rebuild dry-run` from a clean checkout. Only the 9 in-scope hosts are physically provisioned; the cutover spec provisions the deferred 3. Resolved in FR-009 and SC-002.
- Q3: HLC PS1 design — silicon reuse or HLC-themed? → A: HLC-themed, "happy little cloud" motif (small ASCII or Unicode cloud glyph) alongside username/hostname; visibly distinct local vs. remote, mirroring silicon's local/remote behavior. Exact glyph and color finalized during planning. Resolved in FR-017.
- Q4: HLC PS1 glyph palette? → A: `☁⛰☁` (cloud + mountain + cloud). Mountain glyph emoji-presentation handling deferred to plan. Resolved in FR-017.
- Q5: HLC PS1 layout — where do glyphs sit? → A: Glyphs sit between user@host and cwd in the remote form. (Initially answered as a single unified layout; superseded by Q7 once local/remote forms were split.) Resolved in FR-017.
- Q6: HLC PS1 color scheme? → A: Split. Local prompt keeps silicon's existing Gruvbox color treatment (operator's terminal is unconstrained). Remote prompt is no-color (xterm-safe over SSH); bold permitted on glyphs only. Resolved in FR-017.
- Q7: HLC PS1 local-vs-remote forms? → A: Local = silicon's structure with `☁⛰☁` substituting `////` (single-line, color preserved). Remote = two-line box-drawing per `remote-ps1.txt` (`┌─╸user@fqdn ☁⛰☁ [cwd]` then `└──╸$`), no color, FQDN. Resolved in FR-017.

### Session 2026-04-30

- Q9: smoke-test implementation — PTY or non-PTY SSH? → A: Non-PTY only. `ssh -t` caused the Pi to hang at login during testing; normal non-PTY SSH from desktop works correctly. Smoke test MUST: (1) remove SSH host key from `~/.ssh/known_hosts` for both node IP and hostname before testing; (2) verify IP reachability via `ping -c 1 -W 3 <IP>`; (3) verify non-PTY SSH login succeeds on the hostname (`uname -a`, no `-t`). PTY test (`ssh -t`) is removed from scope. Resolved in FR-024 `smoke-test` target.
- Q10: SD bootstrap PAM/sshd blocking — root cause and fix? → A: `pam_systemd` D-Bus session teardown after non-PTY SSH commands blocks sshd accept for several minutes. Fix: `security.pam.services.sshd.startSession = lib.mkForce false` in `modules/sd/bootstrap.nix` (W-004 in specs/WORKAROUNDS.md — resolved as no-op; permanent bootstrap-scoped fix, no removal needed). Provisioned nodes unaffected. Reflected in Edge Cases.
- Q8: Phase rollout cadence — per-module canary or phase bundle? → A: **Phase bundle is the default cadence for US4** (Option B); operator MAY sub-chunk to per-module or sub-bundle scope at implementation time per the "Per-phase cadence" section in `tasks.md`. Constitution v1.3.2 §IV admits all three canary scopes (single module, sub-bundle, full phase bundle) so long as the canary + smoke-test gate is honored before any fleet roll. Default flow: `/speckit-implement` runs all module-creation tasks within a phase, then a single canary on `hlc-501` with the full bundle. Smoke-test green → fleet roll. On smoke-test fail → rollback + bisect via the `/speckit-debug` skill (comment out / git-revert new modules, reintroduce one at a time) to isolate the breaking module. Downstream amendments applied: W-001 ledger admits phase-bundle scope as the default exit path; Constitution IV PATCH bump (v1.3.1 → v1.3.2) clarifies canary scope = change set; plan Phase 5 phasing notes updated; tasks.md US4 restructured around a single canary at T083 with bisect-on-fail. FR-024's manual-canary procedure (`update-node` → `smoke-test` → manual `rollback`) still applies; only the *scope* of one canary expands from one module to one bundle (operator's choice).

### Session 2026-05-04

- Q: How should USB disks be identified in disko? → A: By `/dev/disk/by-path/` using the non-versioned `platform-xhci-hcd.N-usb-0:1:1.0-scsi-0:0:0:0` pattern. Controller index `N=0` = left (a) port, `N=1` = right (b) port. Operator always inserts a-drives left, b-drives right. Confirmed hlc-501: disk-a = `platform-xhci-hcd.0-usb-0:1:1.0-scsi-0:0:0:0` → sda; disk-b = `platform-xhci-hcd.1-usb-0:1:1.0-scsi-0:0:0:0` → sdb. Resolved in FR-010a.
- Q: Must both RAID drives show `usbv3` before provisioning? → A: Yes. A `usbv2` alias means the drive negotiated USB 2.0 speed (transient; re-seating fixes it). Provisioning MUST NOT proceed until both drives show `usbv3`. Resolved in FR-010a.
- Q: Does USB insertion order affect disko disk identification? → A: Insertion order affects kernel device names (`sda`/`sdb`) but NOT `/dev/disk/by-path/` identifiers. Confirmed on hlc-504: plugging B before A caused B→`sda`, A→`sdb`, but by-path still correctly maps `xhci-hcd.0`→left(A) and `xhci-hcd.1`→right(B). Disko operates on by-path, so RAID is built correctly regardless of insertion order. This validates FR-010a's by-path rationale. Resolved in Edge Cases.
- Note (hardware status as of 2026-05-08): All work-set nodes online and provisionable except hlc-503 and hlc-507 (hardware issues; tracked in Makefile `DECOM_HOSTS`). All online Pi 5 nodes confirmed: mdadm array at `/dev/md127` mounted as `/`, NVMe present and confirmed working. hlc-401 online and ready. Phase 5 gate may be tagged with documented exceptions for nodes tracked in `DECOM_HOSTS`; those nodes are provisioned once hardware issues resolve.
- Q: Provisioning SSH user — root or bob? → A: `bob` is the only SSH user on the SD bootstrap image (passwordless key auth); root SSH login is not available. The `nixos-anywhere` provisioning workflow MUST connect as `bob` (not root). Resolved in FR-012 and FR-020.
- Q: Does SD bootstrap `bob` need passwordless sudo for nixos-anywhere? → A: Yes, already configured. `bob` has passwordless sudo in the bootstrap image (`modules/sd/bootstrap.nix`). `nixos-anywhere` connects as `bob@<host>`; no explicit sudo flag is required on the invocation — passwordless sudo on the target is sufficient (confirmed 2026-05-05). This is bootstrap-scoped only; full per-host sudo policy is independent. Resolved in FR-012.

### Session 2026-05-01

- Q11: `/speckit-debug` trigger — auto-load context or operator-described? → A: Operator describes the issue; skill starts from operator's description with no automatic context pre-loading. Resolved in FR-028.
- Q12: `/speckit-debug` physical-access constraint? → A: Hard constraint. Cluster nodes are fully headless; zero physical-access debugging paths are permitted. All diagnostic steps MUST be achievable over the network via SSH from gibson. The skill MUST NOT suggest HDMI, serial console, keyboard, or any step requiring physical access to a node. Resolved in FR-028.
- Q13: `/speckit-debug` operator-trust model? → A: Operator observations are the primary source of truth, but operators can make mistakes. The skill MAY surface an alternative hypothesis if it conflicts with the operator's report, but MUST discuss the disagreement explicitly rather than silently pursuing a different theory. The post-mortem failure mode (agent assumed operator was wrong, delayed diagnosis) is the anti-pattern to avoid. Resolved in FR-028.
- Q14: `/speckit-debug` output format? → A: Conversational. No fixed output structure or template; the skill adapts to the issue as described. Resolved in FR-028.
- Q15: `/speckit-debug` context loading? → A: Skill reads the project constitution and `post-mortem-26-04-29.md` at invocation to ground operator-trust rules and cluster constraints. Spec and plan are consulted on demand if the issue requires them. Resolved in FR-028.

### Session 2026-05-11

- Q19: Operator user pattern — bob (HLC), eaglerock (workstation), slimer (future Ecto-1) share shape. Inline per entry point, helper lib, or option-driven module? → A: Option-driven module (Option A). `modules/users/operator.nix` defines option `system.operator = { name; pubkeys; extraGroups ? ["wheel"]; }` and generates `users.users.${name}` with shared defaults (wheel, key-only SSH auth, bash shell, no password, no mutable users). SSH hardening (`PasswordAuthentication=false`, `KbdInteractiveAuthentication=false`) lives in the same module. Imported globally (via `modules/hosts/common.nix` or top-level). Per-context value: `system.operator.name = "bob"` in `modules/cluster/hlc/default.nix`; `"eaglerock"` in `hosts/silicon/configuration.nix`; future `"slimer"` in `modules/cluster/ecto1/default.nix`. Home-manager binding: each operator gets their own `home/<name>.nix` consuming the appropriate tier module (`server.nix` or `workstation.nix`). Closes the W-001 inline-user pattern uniformly across workstation + cluster.
- Q18: `modules/hosts/common.nix` package-list overlap with cluster `modules/shell/utilities.nix` — keep cluster list minimal or unify? → A: Unify (Option B). All packages in `modules/hosts/common.nix` are baseline command-line tools (including k9s, kubectl, helm, kind) wanted on any shell. T053 scope expands: `modules/shell/utilities.nix` consumes the existing `modules/hosts/common.nix` package list verbatim; `modules/hosts/common.nix` then imports `modules/shell/utilities.nix` (and `modules/shell/common.nix` for bash defaults) and removes the inline `environment.systemPackages` block. Cluster nodes inherit the full set via `modules/cluster/common.nix → modules/shell/utilities.nix`. Non-package content of `modules/hosts/common.nix` (nix.settings, time, locale, docker, openssh) stays put and is workstation-scoped for now.
- Q17: Home-manager tier shape — separate HLC overlay module, or inline HLC-specific bits in `home/bob.nix`? → A: Inline (Option B). Tiers stay generic: `modules/home/base.nix` (all), `modules/home/workstation.nix` (silicon-tier, imports base), `modules/home/server.nix` (cluster-tier, imports base; k8s tooling, tmux, KUBECONFIG). Cluster-specific home bits inline in the operator's home file (`home/bob.nix` for HLC; future `home/<ecto-operator>.nix` for Ecto-1, both importing `server.nix`). Mirrors Q16 outcome on the system side — cluster *mechanism* generic at the tier, cluster *values* in the entry point.
- Q16: PS1 + MOTD module location — generic `modules/shell` or cluster-tier? → A: Cluster-tier. Two clusters planned (HLC = rpi, Ecto-1 = Ryzen 9 x64); both will run k3s and share the cluster MOTD/PS1 mechanism but with cluster-specific banner/quote/glyph values. Layout: `modules/cluster/motd.nix` and `modules/cluster/prompt.nix` define mechanism + options (`cluster.motd.banner`, `cluster.motd.quote`, `cluster.prompt.glyph`, `cluster.prompt.mountainGlyph` fallback); `modules/cluster/common.nix` imports them; `modules/cluster/hlc/default.nix` sets HLC values. Ecto-1 values deferred — no module created yet, but mechanism designed for it. Generic shell stuff (utilities pkgs, base bash aliases) stays in `modules/shell/` and is consumed by both cluster and workstation hosts.
