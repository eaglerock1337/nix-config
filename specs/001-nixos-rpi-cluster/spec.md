# Feature Specification: NixOS RPi Cluster Foundation

**Feature Branch**: `001-nixos-rpi-cluster`
**Created**: 2026-04-25
**Status**: Draft
**Input**: User description: "NixOS configuration for Happy Little Cloud RPi k8s cluster (Pi4 control plane + Pi5 workers), with extensible structure for future desktop/laptop and additional cluster configurations."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Cluster Nodes from Source (Priority: P1)

An operator starts with bare Raspberry Pi hardware and uses this repository to produce
bootable SD card images, install NixOS onto each node's USB RAID storage, and form a
functioning 12-node k3s cluster — all from a single `git clone` and a handful of commands.

**Why this priority**: Without this story, the repo delivers no value. It is the entire
point of Phase 1 and is a prerequisite for every other story.

**Independent Test**: Flash SD cards for all 12 nodes, provision with nixos-anywhere,
verify k3s cluster shows 4 server nodes (hlc-401–404) + 8 agent nodes (hlc-501–508) with `kubectl get nodes`.

**Acceptance Scenarios**:

1. **Given** bare SD cards and USB drives, **When** the operator runs the build-image
   and flash-image targets, **Then** each Pi boots into a working NixOS environment.
2. **Given** a booted Pi with a DHCP-assigned IP, **When** the operator runs the
   provision target, **Then** nixos-anywhere installs NixOS to USB RAID and reboots the
   node to the persistent configuration.
3. **Given** all 12 nodes provisioned, **When** the operator brings them online in cluster
   bring-up order, **Then** `kubectl get nodes` shows all 12 nodes in Ready state.
4. **Given** a node failure, **When** the operator re-provisions from source, **Then**
   the node rejoins the cluster without manual state recovery.

---

### User Story 2 - Deploy Workloads via GitOps (Priority: P2)

An operator bootstraps ArgoCD on the cluster and subsequently manages all application
deployments via Git — no manual `kubectl apply` after initial setup.

**Why this priority**: Without GitOps, cluster management becomes imperative and
untrackable. This is the primary operational model for the cluster.

**Independent Test**: Bootstrap ArgoCD, push an app-of-apps manifest, verify Longhorn,
cert-manager, and ingress deploy automatically via ArgoCD sync.

**Acceptance Scenarios**:

1. **Given** a running k3s cluster, **When** the operator runs the ArgoCD bootstrap
   command, **Then** ArgoCD is running and watching the repo.
2. **Given** ArgoCD running, **When** a Helm chart version is updated in Git,
   **Then** ArgoCD syncs and upgrades the application without operator intervention.
3. **Given** Longhorn deployed, **When** a workload requests a PersistentVolumeClaim,
   **Then** Longhorn provisions storage from the NVMe drives on Pi5 worker nodes.
4. **Given** cert-manager deployed, **When** an Ingress resource is created with
   a marks.dev hostname, **Then** TLS is provisioned automatically.

---

### User Story 3 - Add New Hosts Without Structural Rework (Priority: P3)

An operator adds a new host (a new cluster node, a desktop, or a laptop) to the
repository by writing a thin host config that imports shared modules — without
modifying existing host configs or module files.

**Why this priority**: The repository must grow gracefully. The current
`hosts/silicon` config is the prototype; the 12 cluster nodes validate the pattern
at scale.

**Independent Test**: Add `hosts/hlc-501` config importing shared modules, verify
`nixos-rebuild dry-run --flake .#hlc-501` succeeds without modifying any other file.

**Acceptance Scenarios**:

1. **Given** an existing repository with cluster modules, **When** an operator creates
   a new host directory and thin config file, **Then** the flake evaluates for that
   host without errors.
2. **Given** a future desktop/laptop host, **When** its config imports appropriate
   desktop modules, **Then** it builds without touching cluster-specific modules.
3. **Given** a future ecto-1 Ryzen cluster host, **When** its config imports shared
   k8s modules, **Then** cluster-specific Pi config does not pull in.

---

### User Story 4 - Consistent Shell Environment Across Systems (Priority: P3)

An operator SSHs into any managed system and finds a familiar, well-equipped shell
with the correct user, curated CLI tools, a cluster-branded MOTD, and a quick
reference for available sysadmin utilities.

**Why this priority**: A consistent operator experience across all nodes reduces
cognitive load and mistakes. The MOTD and tooling reference serve as living
documentation. This is foundational infrastructure that every other story benefits
from.

**Independent Test**: SSH into an HLC node as `bob`, verify MOTD displays the
HLC ASCII banner with hostname and quote, confirm standard tools are available,
run the sysadmin reference command to see installed utilities.

**Acceptance Scenarios**:

1. **Given** a provisioned HLC node, **When** the operator SSHs in as `bob`,
   **Then** the MOTD displays the HLC ASCII art banner, node hostname, and a
   Bob Ross quote.
2. **Given** any managed system, **When** the operator runs the sysadmin reference
   command, **Then** a categorized list of installed CLI tools with brief
   descriptions is displayed.
3. **Given** a new cluster type (ecto-1), **When** its config imports the shell
   module with a different user and MOTD theme, **Then** the shell environment
   uses `slimer` as user and the ecto-1 splash screen.
4. **Given** a desktop system, **When** its config imports the shell module,
   **Then** user `eaglerock` has the same standard utilities without any
   cluster-specific MOTD.

---

### User Story 5 - Maintain Cluster Configuration Over Time (Priority: P5)

An operator updates NixOS inputs, k3s version, or cluster secrets, and rolls the
change across all 12 nodes without cluster downtime and without manual imperative steps.

**Why this priority**: A cluster that cannot be updated safely becomes a liability.
Day-2 operations must be as declarative as Day-0 provisioning.

**Independent Test**: Run `nix flake update`, verify dry-run passes, roll update
sequentially across Pi4s then Pi5s, confirm cluster remains healthy throughout.

**Acceptance Scenarios**:

1. **Given** a new nixpkgs revision in flake.lock, **When** the operator runs the
   update-cluster target, **Then** all 12 nodes adopt the new configuration
   sequentially without the cluster losing quorum.
2. **Given** a rotated k3s token, **When** the operator re-encrypts the secret and
   runs update-cluster, **Then** all nodes pick up the new token without a full reset.
3. **Given** a broken node configuration, **When** the operator pushes a fix,
   **Then** only the affected node is rebuilt; remaining nodes are unaffected.

---

### Edge Cases

- What happens when a USB drive in the RAID1 pair fails mid-provision?
- How does the system handle a Pi5 where the NVMe is not detected at boot?
- What if nixos-anywhere loses SSH connectivity partway through installation?
- What happens when k3s token file is absent on a node at first boot?
- How does cluster respond if hlc-401 (init server) is temporarily unreachable during
  a rolling update of the other server nodes?
- What happens if DNS is cut over to a NixOS node before workload migration is
  complete on the old Debian node? How is traffic drained gracefully?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Repository MUST produce a bootable NixOS SD card image for each supported
  Pi model (RPi 4, RPi 5) using a single build command per model.
- **FR-002**: Repository MUST support unattended provisioning of each node via
  nixos-anywhere over SSH from the operator's workstation.
- **FR-003**: Each node's root filesystem MUST reside on a USB RAID1 mirror for
  redundancy; the SD card MUST serve only as the boot layer.
- **FR-004**: Pi5 worker nodes MUST expose NVMe storage for Longhorn distributed
  storage; NVMe MUST NOT be used as the root filesystem.
- **FR-005**: All cluster secrets (k3s join token) MUST be encrypted at rest in the
  repository and decrypted at runtime using host SSH keys as age recipients.
- **FR-006**: The k3s control plane MUST use 4-node embedded etcd (hlc-401–404,
  all Pi4 server nodes) for high availability; these nodes also run lightweight
  workloads. No external etcd is required.
- **FR-007**: k3s worker nodes (Pi5) MUST join the cluster via the control plane VIP
  or primary server address; agent config MUST NOT hard-code individual server IPs.
- **FR-008**: The module structure MUST separate cluster-agnostic k8s concerns
  (k3s role config, Longhorn prereqs) from cluster-specific concerns (HLC node config,
  Pi hardware config) so future clusters reuse the k8s layer without modification.
- **FR-009**: Repository MUST include stub modules for the future ecto-1 cluster
  to validate the extensible module structure without implementing ecto-1.
- **FR-010**: The Makefile (or equivalent) MUST expose targets for: build-image,
  flash-image, provision, update-node, update-cluster, and encrypt-secret.
  The `update-node` target MUST use `nixos-rebuild switch --flake .#<host> --target-host`
  (workstation builds and pushes closure) as the primary path. SSH login is not a
  Makefile target; operators connect directly via `ssh bob@<hostname>`.
- **FR-011**: All nodes MUST be reachable via SSH as user `bob` using the operator's
  existing SSH key; password authentication MUST be disabled.
- **FR-012**: Longhorn MUST use NixOS-compatible container images; upstream default
  images that assume glibc paths MUST be overridden via ArgoCD Helm values.
- **FR-013**: Each system class MUST configure a distinct default user: `bob` for
  HLC cluster nodes, `eaglerock` for gaming/desktop systems, `slimer` for ecto-1
  cluster nodes. User config MUST be a shared module parameterized by username.
- **FR-014**: All systems MUST share a standard shell environment module providing
  a curated set of sysadmin CLI utilities (e.g. htop, ripgrep, jq, tmux, git, etc.)
  and consistent bash/zsh configuration. The module MUST include both: (a) a shell
  command (e.g. `syshelp`) that prints a categorized, colorized list of installed
  tools with one-line descriptions, and (b) a markdown reference doc in the repo
  for onboarding context. The shell prompt (PS1) MUST match the `silicon` system's
  styled prompt, adapted for the cluster username (`bob`) and node hostname. `git`
  MUST be included in the standard tool set to support on-device config pulls.
- **FR-015**: Each cluster MUST display a custom MOTD on SSH login, including
  cluster name and node hostname. HLC nodes MUST display an ASCII art splash
  screen replicating the existing Debian MOTD style (ASCII "HLC" banner, Bob Ross
  quote). The ecto-1 stub MUST use a generic hostname-only banner as placeholder.
  MOTD MUST be implemented as a parameterized NixOS module, not a static file.
- **FR-016**: The standard shell utilities module MUST be implemented first for HLC
  nodes, then generalized for reuse by desktop and future cluster configurations.

### Key Entities

- **Cluster Node**: A physical Pi with hostname, role (server/agent), IP, MAC address,
  and an age public key derived from its SSH host key.
- **NixOS Configuration**: Declarative host config composed of shared modules +
  host-specific overrides; lives under `hosts/<hostname>/`.
- **Cluster Secret**: An encrypted value (k3s token) stored in `secrets/hlc.yaml`;
  decryptable by admin age key and all 12 node host keys.
- **SD Image**: A bootable NixOS disk image flashed to MicroSD; provides firmware,
  kernel, and initramfs; not used for persistent state.
- **USB RAID Pair**: Two USB 3.2 drives per node configured as mdadm RAID1; holds
  the root filesystem for durability.
- **NVMe Volume**: 1TB NVMe per Pi5; dedicated to Longhorn PV storage, not root.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 12 nodes can be provisioned from a clean git checkout in under 4
  hours of operator wall-clock time (excluding SD card flashing time).
- **SC-002**: `kubectl get nodes` shows all 12 nodes in Ready state within 15 minutes
  of the last node being provisioned.
- **SC-003**: A single node failure leaves the cluster fully operational; remaining
  11 nodes serve workloads without intervention.
- **SC-004**: Adding a new host requires creating at most 2 new files (host config +
  optional hardware module) with no changes to existing files.
- **SC-005**: A full cluster rolling update completes without the cluster ever dropping
  below 2 healthy server nodes (preserving etcd quorum).
- **SC-006**: All cluster secrets are unreadable in plaintext in the git repository;
  decryption requires either the admin private key or a node's SSH host key.
- **SC-007**: `nixos-rebuild dry-run` for any host succeeds from a clean checkout
  without network access beyond the configured binary caches.

## Clarifications

### Session 2026-04-26

- Q: What is the primary update mechanism for cluster nodes, and is on-device rebuild supported? → A: Both — workstation push via `nixos-rebuild --target-host` is primary; on-device `git pull` + `nixos-rebuild switch` is a supported fallback for debugging/bootstrapping.
- Q: What should the shell prompt (PS1) look like for cluster nodes? → A: Match `silicon`'s styled prompt, adapted for user `bob` and cluster hostnames.
- Q: Should the Makefile include SSH login convenience targets? → A: No — Makefile covers build/provision/update only; SSH directly via `ssh bob@<hostname>`.

### Session 2026-04-25

- Q: What is the migration strategy for the existing 12-node Debian cluster? → A: Parallel cluster — stand up NixOS nodes alongside existing Debian cluster, migrate workloads, then decommission old nodes. Must include a plan for DNS cutover and Unifi router/switch reconfiguration (DHCP reservations, VLANs, firewall rules) to avoid downtime during the transition.
- Q: Should standard shell environment (users, MOTD, shell utilities, sysadmin tooling) be in this feature spec? → A: Yes, include as first-class requirements. Prioritize HLC cluster implementation first, then generalize for other systems (gaming/ecto-1).
- Q: Are Pi4 workers being replaced by Pi5s or kept alongside? → A: Replace — all 8 Pi4 workers (hlc-301–308) are decommissioned. 8 new Pi5s (hlc-501–508) with NVMe replace them. Cluster remains 12 nodes: 4 Pi4 control plane (hlc-401–404, embedded etcd + lightweight workloads) + 8 Pi5 workers (hlc-501–508, NVMe/Longhorn storage).
- Q: What form should the sysadmin tool reference take? → A: Both — a shell command (e.g. `syshelp`) that prints a categorized, colorized list of installed utilities with one-line descriptions, plus a markdown doc in the repo for onboarding context.
- Q: What theme/branding should the ecto-1 stub MOTD use? → A: Generic placeholder — simple hostname banner with no theme until ecto-1 is fully implemented.

## Assumptions

- The operator's workstation (gibson, Ryzen 9 5950X, NixOS) is the build machine;
  all cross-compilation and image builds run there.
- Network infrastructure (Unifi, DHCP server at 10.23.50.x subnet) is already in
  place and will receive static DHCP reservations per the PREP.md address plan.
- The existing Debian-based HLC cluster will remain running during NixOS provisioning.
  New NixOS nodes will use separate IPs/hostnames initially; DNS and DHCP will be
  cut over per-node once validated. A migration runbook covering DNS, DHCP, and Unifi
  switch port config is in scope for planning.
- The `raspberry-pi-nix` flake input (or equivalent) provides working aarch64-linux
  NixOS images for both RPi 4 and RPi 5; no custom kernel patches are in scope.
- Mobile/GUI desktop environment config for `silicon` (the operator's laptop/desktop)
  is out of scope for this feature; the repository already manages silicon.
- ecto-1 cluster implementation is out of scope; only stub modules are required.
- ArgoCD bootstrap is a one-time manual `kubectl apply`; subsequent management is
  fully GitOps.
- On-device `nixos-rebuild switch` is a supported fallback update path: the operator
  can `git clone/pull` this repo directly onto a node and rebuild locally. This is
  secondary to workstation-push (`update-node` Makefile target) and is intended for
  debugging or bootstrapping scenarios; Pi hardware build times and RAM limits make
  it impractical for routine cluster-wide updates.
- Longhorn's NixOS compatibility issue (glibc path assumptions) is resolved by
  substituting `ghcr.io/duckfullstop/nixos-longhorn-manager` via Helm values.
- The k3s token is chosen before provisioning node 1 and does not change during
  the cluster lifetime without a full reset procedure.
- All Pi5 NVMe drives (Corsair MP600 Micro 1TB) are formatted and managed entirely
  by Longhorn; no manual partitioning is required before provisioning.
