# Feature Specification: NixOS RPi Cluster Foundation

**Feature Branch**: `001-nixos-rpi-cluster`
**Created**: 2026-04-25
**Status**: Draft
**Input**: User description: "NixOS configuration for Happy Little Cloud RPi k8s cluster (Pi4 control plane + Pi5 workers), with extensible structure for future desktop/laptop and additional cluster configurations."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Cluster Nodes from Source (Priority: P1)

Operator start with bare RPi hardware. Use repo to make bootable SD card images, install NixOS to each node USB RAID, form 12-node k3s cluster — all from one `git clone` + few commands.

**Why this priority**: No this story = no value. Whole point of Phase 1. Prereq for every other story.

**Independent Test**: Flash SD cards for all 12 nodes, provision via nixos-anywhere, verify k3s cluster show 4 server nodes (hlc-401–404) + 8 agent nodes (hlc-501–508) with `kubectl get nodes`.

**Acceptance Scenarios**:

1. **Given** bare SD cards + USB drives, **When** operator run build-image
   + flash-image targets, **Then** each Pi boot into working NixOS.
2. **Given** booted Pi with DHCP IP, **When** operator run
   provision target, **Then** nixos-anywhere install NixOS to USB RAID + reboot
   node to persistent config.
3. **Given** all 12 nodes provisioned, **When** operator bring online in cluster
   bring-up order, **Then** `kubectl get nodes` show all 12 Ready.
4. **Given** node failure, **When** operator re-provision from source, **Then**
   node rejoin cluster, no manual state recovery.

---

### User Story 2 - Deploy Workloads via GitOps (Priority: P2)

Operator bootstrap ArgoCD on cluster. After, manage all app deploys via Git — no manual `kubectl apply` after setup.

**Why this priority**: No GitOps = imperative + untrackable. Primary operational model.

**Independent Test**: Bootstrap ArgoCD, push app-of-apps manifest, verify Longhorn,
cert-manager, ingress deploy auto via ArgoCD sync.

**Acceptance Scenarios**:

1. **Given** running k3s cluster, **When** operator run ArgoCD bootstrap
   command, **Then** ArgoCD running + watching repo.
2. **Given** ArgoCD running, **When** Helm chart version updated in Git,
   **Then** ArgoCD sync + upgrade app, no operator action.
3. **Given** Longhorn deployed, **When** workload request PVC,
   **Then** Longhorn provision storage from NVMe on Pi5 workers.
4. **Given** cert-manager deployed, **When** Ingress made with
   marks.dev hostname, **Then** TLS provisioned auto.

---

### User Story 3 - Add New Hosts Without Structural Rework (Priority: P3)

Operator add new host (cluster node, desktop, laptop) by writing thin host config that imports shared modules — no edit to existing host configs or modules.

**Why this priority**: Repo must grow gracefully. Current
`hosts/silicon` config is prototype; 12 cluster nodes validate pattern at scale.

**Independent Test**: Add `hosts/hlc-501` config importing shared modules, verify
`nixos-rebuild dry-run --flake .#hlc-501` succeed, no other file touched.

**Acceptance Scenarios**:

1. **Given** existing repo with cluster modules, **When** operator make
   new host dir + thin config, **Then** flake evaluate for that
   host, no errors.
2. **Given** future desktop/laptop host, **When** config import desktop
   modules, **Then** build, no touch cluster modules.
3. **Given** future ecto-1 Ryzen cluster host, **When** config import shared
   k8s modules, **Then** Pi-specific config not pulled in.

---

### User Story 4 - Consistent Shell Environment Across Systems (Priority: P3)

Operator SSH into any managed system, find familiar shell with right user, curated CLI tools, cluster-branded MOTD, quick reference for sysadmin utils.

**Why this priority**: Consistent operator UX across nodes cut cognitive load + mistakes. MOTD + tool reference = living docs. Foundational — every other story benefit.

**Independent Test**: SSH into HLC node as `bob`, verify MOTD show
HLC ASCII banner + hostname + quote, confirm standard tools present,
run sysadmin reference command to see utils.

**Acceptance Scenarios**:

1. **Given** provisioned HLC node, **When** operator SSH as `bob`,
   **Then** MOTD show HLC ASCII banner, hostname, Bob Ross quote.
2. **Given** any managed system, **When** operator run sysadmin reference
   command, **Then** categorized list of installed CLI tools w/ short
   descriptions show.
3. **Given** new cluster type (ecto-1), **When** config import shell
   module with different user + MOTD theme, **Then** shell env
   use `slimer` user + ecto-1 splash.
4. **Given** desktop system, **When** config import shell module,
   **Then** user `eaglerock` get same standard utils, no
   cluster MOTD.

---

### User Story 5 - Maintain Cluster Configuration Over Time (Priority: P5)

Operator update NixOS inputs, k3s version, or cluster secrets. Roll change across all 12 nodes, no downtime, no manual imperative steps.

**Why this priority**: Cluster that no update safely = liability.
Day-2 ops must be declarative as Day-0 provisioning.

**Independent Test**: Run `nix flake update`, verify dry-run pass, roll update
sequential Pi4s then Pi5s, confirm cluster healthy throughout.

**Acceptance Scenarios**:

1. **Given** new nixpkgs revision in flake.lock, **When** operator run
   update-cluster target, **Then** all 12 nodes adopt new config
   sequential, no quorum loss.
2. **Given** rotated k3s token, **When** operator re-encrypt secret +
   run update-cluster, **Then** all nodes pick up new token, no full reset.
3. **Given** broken node config, **When** operator push fix,
   **Then** only affected node rebuilt; others untouched.

---

### Edge Cases

- USB drive in RAID1 pair fail mid-provision?
- Pi5 NVMe not detected at boot?
- nixos-anywhere lose SSH partway through install?
- k3s token file absent on node at first boot?
- hlc-401 (init server) unreachable during
  rolling update of other server nodes?
- DNS cut over to NixOS node before workload migration done on old Debian node? Drain traffic how?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Repo MUST produce bootable NixOS SD card image for each Pi
  model (RPi 4, RPi 5), one build command per model.
- **FR-002**: Repo MUST support unattended provisioning per node via
  nixos-anywhere over SSH from operator workstation. Target Pi MUST have
  baseline OS + SSH; nixos-anywhere invoked after baseline ready. Password prompts OK if documented as workarounds.
- **FR-003**: Each node root fs MUST live on USB RAID1 mirror for
  redundancy; SD card MUST be boot layer only. RAID1 MUST be
  verified before production workloads. Monitoring + alerting
  for RAID degradation deferred to polishing phase (planned alongside Prometheus/Grafana).
- **FR-004**: Pi5 workers MUST expose NVMe for Longhorn distributed
  storage; NVMe MUST NOT be root fs. At least one partition per
  Pi5 MUST be Longhorn; other partitions may be reserved for other
  uses. NVMe model: Corsair MP600 Micro 1TB per node (already bought).
- **FR-005**: All cluster secrets (k3s join token) MUST be encrypted at rest in
  repo, decrypted at runtime via host SSH keys as age recipients.
- **FR-006**: k3s control plane MUST use 4-node embedded etcd (hlc-401–404,
  all Pi4 servers) for HA; these nodes also run lightweight
  workloads (CPU/memory bound by Pi4; Pi4 = limit factor,
  not Pi5). No external etcd needed.
- **FR-007**: k3s workers (Pi5) MUST join cluster via control plane discovery;
  agent config MUST NOT hardcode server IPs. Discovery mechanism (VIP, DNS
  round-robin, primary server IP) deferred pending arch deliberation.
- **FR-008**: Module structure MUST split cluster-agnostic k8s concerns
  (k3s role config, Longhorn prereqs) from cluster-specific (HLC node config,
  Pi hw config) so future clusters reuse k8s layer unmodified.
- **FR-009**: Repo MUST include stub modules for future ecto-1 cluster
  to validate extensible module structure, no ecto-1 impl.
- **FR-010**: Makefile (or equivalent) MUST expose targets: build-image,
  flash-image, provision, update-node, update-cluster, encrypt-secret.
  `update-node` target MUST use `nixos-rebuild switch --flake .#<host> --target-host`
  (workstation builds + pushes closure) as primary path. `encrypt-secret`
  target details (input/output format) deferred; existence + basic
  func required for MVP. SSH login not Makefile target;
  operators connect direct via `ssh bob@<hostname>`.
- **FR-011**: All nodes MUST be reachable via SSH as `bob` using operator's
  SSH key; password auth MUST be off. For MVP, `bob`'s
  authorized_keys hardcoded in NixOS module; migration to secrets mgmt
  (sops-nix) planned for later.
- **FR-012**: Longhorn MUST use NixOS-compat container images; upstream defaults
  that assume glibc paths MUST be overridden via ArgoCD Helm values.
- **FR-013**: Each system class MUST configure distinct default user: `bob` for
  HLC nodes, `eaglerock` for gaming/desktop, `slimer` for ecto-1
  nodes. User config MUST be shared module parameterized by username.
- **FR-014**: All systems MUST share standard shell env module providing
  curated sysadmin CLI utils (e.g. htop, ripgrep, jq, tmux, git, etc.)
  + bash as canonical shell (zsh out of scope). For MVP testing phase, module
  use default bash prompt, no custom PS1, no syshelp, no
  custom bashrc — pure NixOS defaults + tool packages. Styled PS1 (matching
  `silicon`'s prompt, adapted for `bob` + cluster hostnames), `syshelp`
  command, markdown reference doc deferred to stable testing phase after SSH
  verified across all nodes. `git` MUST be included for on-device
  config pulls.
- **FR-015**: Each cluster MUST show custom MOTD on SSH login, including
  cluster name + hostname. HLC nodes MUST show ASCII art splash
  matching existing Debian MOTD style (ASCII "HLC" banner, Bob Ross
  quote). ecto-1 stub MUST use generic hostname-only banner placeholder.
  MOTD MUST be parameterized NixOS module, not static file.
- **FR-016**: Standard shell utils module MUST be implemented first for HLC
  nodes, then generalized for desktop + future cluster reuse.

### Key Entities

- **Cluster Node**: Physical Pi w/ hostname, role (server/agent), IP, MAC,
  age public key derived from SSH host key.
- **NixOS Configuration**: Declarative host config = shared modules +
  host-specific overrides; lives under `hosts/<hostname>/`.
- **Cluster Secret**: Encrypted value (k3s token) in `secrets/hlc.yaml`;
  decryptable by admin age key + all 12 node host keys.
- **SD Image**: Bootable NixOS disk image flashed to MicroSD; provides firmware,
  kernel, initramfs; not for persistent state.
- **USB RAID Pair**: Two USB 3.2 drives per node = mdadm RAID1; holds
  root fs for durability.
- **NVMe Volume**: 1TB NVMe per Pi5; Longhorn PV storage only, not root.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 12 nodes provisionable from clean git checkout in under 4
  hours operator wall-clock (excluding SD flash time).
- **SC-002**: `kubectl get nodes` show all 12 Ready within 15 min
  of last node provisioned.
- **SC-003**: Single node failure leave cluster fully operational; remaining
  11 nodes serve workloads, no intervention.
- **SC-004**: Adding new host need at most 2 new files (host config +
  optional hw module), no edit to existing files.
- **SC-005**: Full cluster rolling update done without dropping
  below 2 healthy server nodes (etcd quorum preserved).
- **SC-006**: All cluster secrets unreadable in plaintext in git;
  decryption need admin private key or node SSH host key.
- **SC-007**: `nixos-rebuild dry-run` for any host succeed from clean checkout
  with no network beyond configured binary caches.

## Clarifications

### Session 2026-04-26 (Round 4)

- Q: What baseline should shell module provide for MVP testing after PS1/kitty issues found? → A: Basic — default bash prompt, standard tool packages (htop, git, jq, tmux, ripgrep, etc.), no custom PS1 styling. PS1 styling, syshelp, custom bashrc deferred to stable testing phase after SSH verified.

### Session 2026-04-26 (Round 3)

- Q: Which shell canonical for cluster nodes? → A: Bash only; zsh out of scope.
- Q: Does ecto-1 stub need dry-run validation for MVP? → A: No. Spec structure must support future ecto-1 inclusion; no stub files or dry-run required for MVP.
- Q: Does SC-004 ("no changes to existing files") conflict with flake.nix wiring? → A: Accepted exception. Host config file + flake.nix entry is required pattern, satisfies SC-004 intent.

### Session 2026-04-26 (Round 2)

- Q: What initial state target Pi need before nixos-anywhere? → A: OS running w/ SSH; baseline SD card as start point.
- Q: Password prompts acceptable in unattended provisioning? → A: Yes, if documented as workarounds; preferred path keyless.
- Q: Sequence for bob user + SSH keys? → A: bob + SSH keys must be set up by nixos-anywhere provisioning; this is the requirement, not prior setup.
- Q: NVMe disk model + capacity? → A: Corsair MP600 Micro 1TB (already bought); hard requirement.
- Q: NVMe partitioning — full device or partition? → A: One partition min for Longhorn; others may be reserved for future use.
- Q: Definition of "lightweight workloads" on Pi4 control plane? → A: CPU/memory limited by Pi4 hw; Pi4 is constraint vs Pi5.
- Q: RAID1 redundancy — what entail? → A: RAID1 must be verified before prod use; monitoring/alerting deferred to polishing phase.
- Q: Agent discovery mechanism (VIP, DNS, hardcoded IP)? → A: Deferred; pending arch deliberation.
- Q: bob SSH key provisioning method? → A: Hardcoded in NixOS module for MVP; sops-nix migration later.
- Q: encrypt-secret target input/output spec? → A: Deferred; existence required for MVP, details wait.

### Session 2026-04-26 (Round 1)

- Q: Primary update mechanism for cluster nodes, on-device rebuild supported? → A: Both — workstation push via `nixos-rebuild --target-host` primary; on-device `git pull` + `nixos-rebuild switch` supported fallback for debug/bootstrap.
- Q: Shell prompt (PS1) for cluster nodes? → A: Match `silicon`'s styled prompt, adapted for `bob` + cluster hostnames.
- Q: Makefile include SSH login convenience targets? → A: No — Makefile covers build/provision/update only; SSH direct via `ssh bob@<hostname>`.

### Session 2026-04-25

- Q: Migration strategy for existing 12-node Debian cluster? → A: Parallel cluster — stand up NixOS nodes alongside Debian, migrate workloads, decommission old. Must include plan for DNS cutover + Unifi router/switch reconfig (DHCP reservations, VLANs, firewall rules) to avoid downtime during transition.
- Q: Standard shell env (users, MOTD, shell utils, sysadmin tooling) in this spec? → A: Yes, first-class requirements. HLC cluster first, then generalize for other systems (gaming/ecto-1).
- Q: Pi4 workers replaced by Pi5s or kept alongside? → A: Replace — all 8 Pi4 workers (hlc-301–308) decommissioned. 8 new Pi5s (hlc-501–508) w/ NVMe replace them. Cluster stays 12: 4 Pi4 control plane (hlc-401–404, embedded etcd + light workloads) + 8 Pi5 workers (hlc-501–508, NVMe/Longhorn storage).
- Q: Form for sysadmin tool reference? → A: Both — shell command (e.g. `syshelp`) printing categorized colorized list of installed utils w/ one-line descriptions, plus markdown doc in repo for onboarding.
- Q: Theme/branding for ecto-1 stub MOTD? → A: Generic placeholder — simple hostname banner, no theme until ecto-1 implemented.

## Assumptions

- Operator workstation (gibson, Ryzen 9 5950X, NixOS) is build machine;
  all cross-compile + image builds run there.
- Network infra (Unifi, DHCP at 10.23.50.x subnet) already in
  place, will get static DHCP reservations per PREP.md plan.
- Existing Debian HLC cluster stays running during NixOS provisioning.
  New NixOS nodes use separate IPs/hostnames initially; DNS + DHCP
  cut over per-node once validated. Migration runbook covering DNS, DHCP, Unifi
  switch port config in scope for planning.
- `raspberry-pi-nix` flake input (or equivalent) provides working aarch64-linux
  NixOS images for both RPi 4 + RPi 5; no custom kernel patches in scope.
- Mobile/GUI desktop env config for `silicon` (operator laptop/desktop)
  out of scope here; repo already manages silicon.
- ecto-1 cluster impl out of scope; only stubs required.
- ArgoCD bootstrap = one-time manual `kubectl apply`; subsequent mgmt
  fully GitOps.
- On-device `nixos-rebuild switch` supported fallback path: operator
  can `git clone/pull` repo directly on node + rebuild local. Secondary
  to workstation-push (`update-node` Makefile target); for
  debug or bootstrap; Pi build times + RAM make
  it impractical for routine cluster-wide updates.
- Longhorn NixOS compat issue (glibc path assumptions) resolved by
  substituting `ghcr.io/duckfullstop/nixos-longhorn-manager` via Helm values.
- k3s token chosen before provisioning node 1; no change during
  cluster lifetime without full reset.
- Kitty terminal (TERM=xterm-kitty) not in default NixOS terminfo on
  nodes; operators using kitty must install kitty terminfo on nodes or connect
  with `TERM=xterm-256color`. Known limitation, not Phase 1 bug.
- All Pi5 NVMe drives (Corsair MP600 Micro 1TB; already bought) unformatted
  before provisioning, managed entirely by Longhorn; no pre-partitioning
  needed from operator.