# Specification Quality Checklist: NixOS RPi Cluster Foundation

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-04-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
- Spec leans technical (k3s, Longhorn, USB RAID, sops-nix) because target audience IS the operator/developer; "non-technical stakeholder" criterion interpreted as "no source-level implementation details" — passed.
- FR-006/FR-007 reference k3s and etcd by name; these are domain terms in the cluster space, not implementation leakage. They define WHAT the system must do (HA control plane, agent join behavior), not HOW.
- Four user stories prioritized P1–P4; P1 alone delivers MVP (provisioned cluster ready for workloads).

---

# Full Requirements Quality Checklist: NixOS RPi Cluster Foundation

**Purpose**: Full-spec requirements quality validation across FR-001–FR-016, edge cases, and assumptions — "unit tests for the English"
**Created**: 2026-04-25
**Feature**: [`spec.md`](../spec.md) | [`plan.md`](../plan.md) | [`data-model.md`](../data-model.md)

---

## Requirement Completeness

- [x] CHK001 - Are build target requirements defined for each supported Pi model individually (Pi4 and Pi5), or does FR-001 leave ambiguity about whether a single unified image is acceptable? [Completeness, Spec §FR-001] — FR-001 says "a single build command per model"; data-model §SDImage confirms exactly two images (one per Pi model). Addressed.
- [x] CHK002 - Does FR-002 (nixos-anywhere) specify what initial state the target Pi must be in before provisioning can begin (running OS, open SSH port, kexec support)? [Completeness, Spec §FR-002] — Addressed: FR-002 clarified to require baseline OS running with SSH access.
- [ ] CHK003 - Are the exact USB drive capacities (2× 64GB) and interface spec (USB 3.2) documented as requirements in the spec, or only as implementation details in the data-model? [Completeness, Gap — data-model has it, spec §FR-003 does not]
- [x] CHK004 - Does FR-003 specify what happens to the SD card after USB RAID provisioning — is it removed, left in place, or still required at runtime for boot? [Completeness, Spec §FR-003] — FR-003 says "SD card MUST serve only as the boot layer." Addressed.
- [x] CHK005 - Is there a requirement specifying the NVMe drive model/capacity (Corsair MP600 Micro 1TB) or are any 1TB NVMe drives acceptable? [Completeness, Gap — Assumptions §6 names a model but FR-004 does not] — Addressed: Corsair MP600 Micro 1TB added to FR-004 as hard requirement.
- [x] CHK006 - Are requirements defined for what "lightweight workloads" on control-plane nodes means — CPU/RAM limits, workload classes allowed, workload classes forbidden? [Completeness, Gap — Spec §FR-006 uses "lightweight" without definition] — Addressed: FR-006 clarified that "lightweight" = CPU/memory constrained by Pi4 hardware; Pi4 is the limiting factor.
- [x] CHK007 - Does FR-007 specify the exact mechanism for agent nodes to discover the control plane (VIP, DNS round-robin, first-server IP hardcoded)? Is VIP a hard requirement or one option? [Clarity, Spec §FR-007] — Addressed/Deferred: FR-007 updated to defer discovery mechanism; pending architectural deliberation.
- [x] CHK008 - Are the ecto-1 stub requirements (FR-009) complete enough to validate the extensible module structure — does the stub need to `dry-run` successfully, or only exist as files? [Completeness, Spec §FR-009] — Addressed: spec structure must support ecto-1 inclusion when the time comes; no dry-run or stub files required for MVP.
- [x] CHK009 - Does FR-010 define what the `encrypt-secret` Makefile target must accept as input and produce as output — or only that the target must exist? [Clarity, Spec §FR-010] — Addressed/Deferred: FR-010 updated to defer target details; target existence required for MVP.
- [x] CHK010 - Are requirements present for how `bob`'s SSH authorized key is provisioned into the repo — is it hardcoded in the module, parameterized, or sourced externally? [Completeness, Spec §FR-011, Gap] — Addressed: FR-011 clarified that authorized_keys is hardcoded in module for MVP; sops-nix migration planned later.
- [x] CHK011 - Is the NixOS-compatible Longhorn image source specified as a hard requirement, or is any compatible image acceptable as long as it works on NixOS? [Clarity, Spec §FR-012, Assumption §8] — FR-012 requires images that don't assume glibc paths and mandates Helm values override; the specific image (`ghcr.io/duckfullstop/nixos-longhorn-manager`) is an Assumption (implementation detail). Requirement is: override via Helm values. Addressed.
- [ ] CHK012 - Does FR-013 document what happens when a new system class is introduced — is adding a new username value to the parameterized module sufficient, or are migration requirements needed? [Completeness, Spec §FR-013]
- [ ] CHK013 - Are the specific sysadmin CLI tools for `syshelp` enumerated in the requirements, or is the curated list left entirely to implementation discretion? [Completeness, Spec §FR-014, Gap]
- [x] CHK014 - Does FR-014 specify whether `syshelp` output must be machine-parseable (JSON, TSV) or only human-readable and colorized? [Clarity, Spec §FR-014] — FR-014 says "categorized, colorized list of installed tools with one-line descriptions." Human-readable output is unambiguous. Addressed.
- [ ] CHK015 - Does FR-015 define the exact content and format of the HLC ASCII art MOTD, or is "replicating the existing Debian MOTD style" sufficient guidance for an implementer? [Clarity, Spec §FR-015]
- [ ] CHK016 - Is there a requirement specifying whether the MOTD must be displayed on all login types (SSH, console, tmux reattach) or only SSH interactive logins? [Completeness, Gap]
- [ ] CHK017 - Does FR-016 define what "generalized for reuse" means concretely — what must a non-HLC system be able to override without modifying the shared module? [Clarity, Spec §FR-016]

---

## Requirement Clarity

- [x] CHK018 - Is "unattended provisioning" in FR-002 defined to mean zero operator keystrokes after `make provision`, or does it permit password/confirmation prompts? [Clarity, Spec §FR-002] — Addressed: FR-002 clarified that password prompts are acceptable if documented as workarounds; keyless path preferred.
- [x] CHK019 - Is "redundancy" in FR-003 defined — does RAID1 alone satisfy it, or are requirements for RAID monitoring, degraded-state alerting, and rebuild also expected? [Clarity, Spec §FR-003] — Addressed: FR-003 clarified that RAID1 must be verified before production; monitoring/alerting deferred to polishing phase.
- [x] CHK020 - Is "dedicated to Longhorn" in FR-004 quantified — does it mean the full NVMe block device, or can a partition be reserved for other use? [Clarity, Spec §FR-004] — Addressed: FR-004 clarified that at least one partition must be dedicated to Longhorn; additional partitions may be reserved.
- [ ] CHK021 - Does "encrypted at rest" in FR-005 specify the encryption algorithm and key length, or is sops-age sufficient as stated? [Clarity, Spec §FR-005]
- [ ] CHK022 - Is "decrypted at runtime" in FR-005 qualified — at which boot stage must the secret be available, and what is the required behavior if decryption fails? [Clarity, Spec §FR-005, Edge Case]
- [ ] CHK023 - Are "cluster-agnostic k8s concerns" (FR-008) explicitly listed so implementers don't have to infer the module separation boundary? [Clarity, Spec §FR-008]
- [x] CHK024 - Is the PS1 prompt format specified in the requirements — or only implied by User Story 4 and elaborated in the plan? [Clarity, Gap — plan §PS1 Prompt Design has this, spec does not] — FR-014 now explicitly says "The shell prompt (PS1) MUST match the `silicon` system's styled prompt, adapted for the cluster username (`bob`) and node hostname." Addressed.
- [x] CHK025 - Does User Story 4 quantify what a "familiar, well-equipped shell" means in terms of specific tools or configuration behaviors? [Clarity, Spec §US-4] — FR-014 provides the quantification: curated CLI utilities (with examples), bash/zsh config, `syshelp` command, markdown reference doc, PS1 requirement, git inclusion. US-4 defers to FR-014. Addressed.
- [x] CHK026 - Is "consistent bash/zsh configuration" in FR-014 defined — which shell is canonical, and what does consistency require between the two? [Clarity, Spec §FR-014] — Addressed: bash is canonical. No zsh requirement for cluster nodes.

---

## Requirement Consistency

- [ ] CHK027 - Does the Longhorn deferral decision (local-path provisioner first, per plan Phase C) conflict with FR-012 and FR-004, which require Longhorn and NVMe setup as stated requirements? Is the phased deferral captured in the spec? [Consistency, Conflict — Spec §FR-004/FR-012 vs plan §Phase C]
- [x] CHK028 - Are user requirements in FR-013 consistent with User Story 4 — US-4 specifies `bob` for HLC; is there a risk the desktop user (`eaglerock`) could be applied to a cluster config via module composition? [Consistency, Spec §FR-013 vs §US-4] — FR-013 uses a parameterized module by username; each system class (`hlc`, `desktop`, `ecto1`) maps to a distinct username. Module composition requires explicit import of the user module with the correct parameter; accidental cross-application would require incorrect explicit configuration. Consistent. Addressed.
- [x] CHK029 - Does FR-011 (SSH only, password auth disabled) align with the provisioning flow in FR-002? How does nixos-anywhere authenticate before SSH host keys and the `bob` user have been established? [Consistency, Spec §FR-002 vs §FR-011] — Addressed: Clarified that bob + SSH keys are established by nixos-anywhere as part of provisioning; baseline OS provides initial SSH access for the tool.
- [x] CHK030 - Is the SC-004 success criterion ("at most 2 new files, no changes to existing files") consistent with the flake.nix wiring step, which unavoidably requires adding a `nixosConfiguration` entry? [Consistency, Spec §SC-004] — Addressed: flake.nix wiring is accepted exception; current pattern (host config file + flake.nix entry) satisfies SC-004 intent.
- [ ] CHK031 - Does SC-007 (dry-run succeeds without network beyond binary caches) account for the sops-nix secrets decryption step, which requires the node's SSH host key to exist? [Consistency, Spec §SC-007]
- [x] CHK032 - Is "cluster node: `bob`" in FR-013 consistent with User Story 4 acceptance scenario 1, which says the operator SSHs in as `bob` and sees HLC MOTD? Are these requirements redundant or do they cover different aspects? [Consistency, Spec §FR-013 vs §US-4-AS-1] — Consistent and complementary: FR-013 defines the user provisioning requirement (parameterized module), US-4 AS-1 defines the end-to-end operator experience. No conflict. Addressed.

---

## Acceptance Criteria Quality

- [ ] CHK033 - Is SC-001 (all 12 nodes provisioned in under 4 hours) measurable given that SD card flashing time is explicitly excluded — is operator wait time vs. total wall-clock time defined? [Measurability, Spec §SC-001]
- [ ] CHK034 - Is SC-002 (all nodes Ready within 15 minutes of last provisioned) measurable with a clear start time — when is "the last node provisioned" considered complete? [Measurability, Spec §SC-002]
- [ ] CHK035 - Does SC-003 ("fully operational" after one node failure) define what "fully operational" means — no degraded storage, no API server impact, or simply no cluster-level downtime? [Clarity, Spec §SC-003]
- [ ] CHK036 - Is SC-005 (rolling update without dropping below 2 healthy servers) testable without a live cluster — is there a dry-run or simulation acceptance path defined? [Measurability, Spec §SC-005]
- [ ] CHK037 - Does SC-006 ("unreadable in plaintext") have a defined verification method — e.g., required `git grep` scan, sops validation, or CI check? [Measurability, Spec §SC-006]
- [ ] CHK038 - Are acceptance criteria defined for the `syshelp` command specifically — must it exit 0, must output be paged, must categories be a fixed set? [Completeness, Gap]

---

## Scenario Coverage

- [ ] CHK039 - Are requirements defined for the case where a Pi fails to boot from USB RAID after nixos-anywhere provisioning — can the operator recover without reprovisioning from scratch? [Coverage, Edge Case §1]
- [ ] CHK040 - Is there a requirement for what the operator must do if `nixos-anywhere` loses SSH connectivity mid-install — retry from scratch, partial recovery, or idempotent re-run? [Coverage, Spec §Edge Cases §4]
- [ ] CHK041 - Are requirements defined for the k3s token-absent scenario — does the node fail to start cleanly, log a specific error, or attempt a retry? [Coverage, Spec §Edge Cases §5]
- [ ] CHK042 - Does the spec define requirements for DNS cutover — traffic draining, health-check gating before cutover, or rollback criteria if the new node misbehaves? [Coverage, Spec §Edge Cases §6]
- [ ] CHK043 - Are rolling update requirements defined for the case where a node fails mid-update and the operator must abort — is stop-on-failure a requirement? [Coverage, Gap]
- [ ] CHK044 - Are requirements specified for the ArgoCD bootstrap failure scenario — what cluster state is acceptable if bootstrap fails partway through the one-time apply? [Coverage, Gap]

---

## Edge Case Coverage

- [ ] CHK045 - Is there a requirement for mdadm RAID1 degraded-state behavior — does NixOS boot normally with one failed USB drive, and is operator notification required? [Edge Case, Spec §Edge Cases §1]
- [ ] CHK046 - Does the spec define requirements for the Pi5 NVMe-not-detected scenario — does provisioning abort, continue without NVMe, or emit a configuration error? [Edge Case, Spec §Edge Cases §2]
- [ ] CHK047 - Are requirements defined for updating `hlc-401` (the init server with `clusterInit=true`) during a rolling update — is there a mandatory sequence or quorum check before updating it? [Edge Case, Spec §US-5, data-model §Rolling Update Sequence]
- [ ] CHK048 - Is there a requirement for duplicate `clusterInit=true` protection — research R-004 notes this causes split-brain, but is a configuration check or CI gate required by spec? [Edge Case, Spec §FR-006]
- [ ] CHK049 - Are requirements defined for Longhorn PV behavior when a Pi5 worker node is decommissioned — data migration, replica rebalancing, or operator runbook? [Edge Case, Gap]

---

## Non-Functional Requirements

- [ ] CHK050 - Are build-time performance requirements specified — e.g., image build must complete within X minutes on gibson — or is build time entirely unbounded? [Performance, Gap]
- [ ] CHK051 - Is there a security requirement specifying which SSH host key types are acceptable (`ed25519` only, or also `rsa`)? [Security, Spec §FR-005]
- [ ] CHK052 - Is there a requirement for secret rotation frequency — how often should the k3s token be rotated, and is a rotation procedure without full cluster reset required? [Security, Gap — Spec §Assumptions §4 says token doesn't change after creation, which is an assumption not a requirement]
- [ ] CHK053 - Are observability requirements defined — must nodes expose metrics (e.g., node-exporter), and is this in scope for Phase A or a later phase? [Non-Functional, Gap]
- [ ] CHK054 - Is there a log retention or centralized logging requirement for cluster nodes? [Non-Functional, Gap]

---

## Dependencies & Assumptions

- [ ] CHK055 - Is the dependency on `raspberry-pi-nix` (archived March 2025) documented in the spec as a risk with explicit fallback requirements — or only noted in research.md? [Dependency, Gap — research.md §R-001 covers this but spec does not]
- [ ] CHK056 - Is the assumption that QEMU aarch64 emulation on gibson is available documented as a prerequisite requirement for operators — or could someone attempt to build without it? [Assumption, Spec §Assumptions §1]
- [ ] CHK057 - Is the Unifi network infrastructure dependency (Assumption §2) validated — are DHCP reservation and VLAN requirements specified in a way an implementer can follow? [Dependency, Spec §Assumptions §2, Gap]
- [ ] CHK058 - Does the assumption that "existing Debian cluster remains running" have a corresponding requirement for minimum overlap period or cutover gate criteria? [Assumption, Spec §Assumptions §3]
- [ ] CHK059 - Is the assumption that all Pi5 NVMe drives are unformatted before provisioning documented as a pre-provisioning check or requirement? [Assumption, Spec §Assumptions §9]

---

## Ambiguities & Conflicts

- [ ] CHK060 - The spec uses "Bob Ross quote" for HLC MOTD (US-4, FR-015) — is this a fixed quote or a rotating one, and if rotating, is the quote source or pool a requirement? [Ambiguity, Spec §FR-015]
- [ ] CHK061 - FR-016 says the shell utilities module must be "implemented first for HLC nodes, then generalized" — is this a delivery sequencing requirement with acceptance criteria, or an implementation guideline? [Ambiguity, Spec §FR-016]
- [ ] CHK062 - The spec lists "ArgoCD bootstrap is a one-time manual `kubectl apply`" as an assumption, but User Story 2 implies the bootstrap command/manifest is a deliverable. Is the manifest in scope or out of scope? [Conflict, Spec §US-2 vs §Assumptions §7]
- [ ] CHK063 - Does "no changes to existing files" in SC-004 apply to `flake.nix`? Adding a `nixosConfiguration` entry for a new host is unavoidable — is this an accepted exception or a gap in SC-004? [Ambiguity, Spec §SC-004]
- [x] CHK064 - Is the PS1 prompt a deliverable of FR-014 (shell environment), or does it belong under FR-015 (MOTD/branding) or FR-016 (shell generalization)? The plan places it in `modules/shell/prompt.nix` but no FR directly requires a PS1 prompt. [Gap — plan §PS1 Prompt Design has no corresponding FR] — FR-014 now explicitly owns PS1: "The shell prompt (PS1) MUST match the `silicon` system's styled prompt, adapted for the cluster username (`bob`) and node hostname." Addressed.
- [ ] CHK065 - Are colorization requirements for `syshelp` output specified — e.g., must it use specific colors consistent with the Gruvbox theme used elsewhere, or any colorization? [Clarity, Spec §FR-014]

---

## Notes (Requirements Quality Run)

- Check items off as completed: `[x]`
- Add findings inline after the item text
- `[Gap]` = requirement is missing and should be added to spec
- `[Ambiguity]` = requirement exists but is underspecified
- `[Conflict]` = two requirements or artifacts are inconsistent
- Items CHK001–CHK065 cover the full spec (FR-001–FR-016, edge cases, assumptions, success criteria)
