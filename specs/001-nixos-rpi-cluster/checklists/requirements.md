# Specification Quality Checklist: NixOS RPi Cluster Foundation

**Purpose**: Validate spec completeness + quality before planning
**Created**: 2026-04-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value + business needs
- [x] Readable by non-technical stakeholders
- [x] All mandatory sections done

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers
- [x] Requirements testable + unambiguous
- [x] Success criteria measurable
- [x] Success criteria tech-agnostic (no impl details)
- [x] All acceptance scenarios defined
- [x] Edge cases identified
- [x] Scope bounded
- [x] Dependencies + assumptions identified

## Feature Readiness

- [x] All FRs have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets Success Criteria measurable outcomes
- [x] No impl details leak into spec

## Notes

- Incomplete items need spec updates before `/speckit-clarify` or `/speckit-plan`
- Spec leans technical (k3s, Longhorn, USB RAID, sops-nix) because target audience IS operator/developer; "non-technical stakeholder" read as "no source-level impl details" — passed.
- FR-006/FR-007 name k3s + etcd; domain terms in cluster space, not impl leak. Define WHAT (HA control plane, agent join), not HOW.
- Four user stories prioritized P1–P4; P1 alone = MVP (cluster ready for workloads).

---

# Full Requirements Quality Checklist: NixOS RPi Cluster Foundation

**Purpose**: Full-spec requirements quality check across FR-001–FR-016, edge cases, assumptions — "unit tests for English"
**Created**: 2026-04-25
**Feature**: [`spec.md`](../spec.md) | [`plan.md`](../plan.md) | [`data-model.md`](../data-model.md)

---

## Requirement Completeness

- [x] CHK001 - Build target reqs defined per Pi model (Pi4, Pi5), or FR-001 ambiguous on unified image? [Completeness, Spec §FR-001] — FR-001 says "single build command per model"; data-model §SDImage confirms two images (one per model). Addressed.
- [x] CHK002 - FR-002 (nixos-anywhere) specify Pi initial state pre-provision (running OS, open SSH, kexec)? [Completeness, Spec §FR-002] — Addressed: FR-002 requires baseline OS + SSH access.
- [ ] CHK003 - USB capacities (2× 64GB) + interface (USB 3.2) documented as spec reqs, or only data-model impl details? [Completeness, Gap — data-model has it, spec §FR-003 does not]
- [x] CHK004 - FR-003 specify SD card fate post USB RAID provision — removed, left, or runtime-required? [Completeness, Spec §FR-003] — FR-003 says "SD card MUST serve only as boot layer." Addressed.
- [x] CHK005 - Req for NVMe model/capacity (Corsair MP600 Micro 1TB), or any 1TB NVMe OK? [Completeness, Gap — Assumptions §6 names model, FR-004 does not] — Addressed: Corsair MP600 Micro 1TB added to FR-004 as hard req.
- [x] CHK006 - "Lightweight workloads" on control-plane defined — CPU/RAM limits, allowed/forbidden classes? [Completeness, Gap — Spec §FR-006 uses "lightweight" undefined] — Addressed: FR-006 says "lightweight" = bound by Pi4 hardware; Pi4 limits.
- [x] CHK007 - FR-007 specify agent control-plane discovery mechanism (VIP, DNS RR, hardcoded IP)? VIP hard req or option? [Clarity, Spec §FR-007] — Addressed/Deferred: FR-007 defers discovery; pending architecture deliberation.
- [x] CHK008 - ecto-1 stub reqs (FR-009) complete enough to validate extensible module structure — stub need `dry-run` success, or just files? [Completeness, Spec §FR-009] — Addressed: structure must support ecto-1 inclusion later; no dry-run/stub files for MVP.
- [x] CHK009 - FR-010 define `encrypt-secret` Makefile target input/output, or only existence? [Clarity, Spec §FR-010] — Addressed/Deferred: FR-010 defers details; existence required for MVP.
- [x] CHK010 - Reqs for how `bob`'s SSH authorized key reaches repo — hardcoded, parameterized, external? [Completeness, Spec §FR-011, Gap] — Addressed: FR-011 says authorized_keys hardcoded in module for MVP; sops-nix migration later.
- [x] CHK011 - NixOS-compatible Longhorn image source hard req, or any compatible image OK? [Clarity, Spec §FR-012, Assumption §8] — FR-012 requires images that don't assume glibc paths + mandates Helm values override; specific image (`ghcr.io/duckfullstop/nixos-longhorn-manager`) is Assumption (impl detail). Req: override via Helm values. Addressed.
- [ ] CHK012 - FR-013 document new system class introduction — adding new username to parameterized module enough, or migration reqs needed? [Completeness, Spec §FR-013]
- [ ] CHK013 - Specific sysadmin CLI tools for `syshelp` enumerated, or curated list left to implementer? [Completeness, Spec §FR-014, Gap]
- [x] CHK014 - FR-014 specify if `syshelp` output machine-parseable (JSON, TSV) or human-readable + colorized? [Clarity, Spec §FR-014] — FR-014 says "categorized, colorized list of installed tools with one-line descriptions." Human-readable unambiguous. Addressed.
- [ ] CHK015 - FR-015 define exact HLC ASCII art MOTD content/format, or "replicate existing Debian MOTD style" enough? [Clarity, Spec §FR-015]
- [ ] CHK016 - Req for MOTD display on all login types (SSH, console, tmux reattach) or only SSH interactive? [Completeness, Gap]
- [ ] CHK017 - FR-016 define "generalized for reuse" concretely — what must non-HLC system override without touching shared module? [Clarity, Spec §FR-016]

---

## Requirement Clarity

- [x] CHK018 - "Unattended provisioning" in FR-002 = zero keystrokes after `make provision`, or password/confirm prompts OK? [Clarity, Spec §FR-002] — Addressed: FR-002 says password prompts OK if documented as workarounds; keyless preferred.
- [x] CHK019 - "Redundancy" in FR-003 defined — RAID1 alone enough, or monitoring/degraded alerts/rebuild expected? [Clarity, Spec §FR-003] — Addressed: FR-003 says RAID1 must be verified pre-prod; monitoring/alerting deferred to polish phase.
- [x] CHK020 - "Dedicated to Longhorn" in FR-004 quantified — full NVMe block device, or partition reserved? [Clarity, Spec §FR-004] — Addressed: FR-004 says at least one partition dedicated to Longhorn; more partitions OK.
- [ ] CHK021 - "Encrypted at rest" in FR-005 specify algo + key length, or sops-age sufficient? [Clarity, Spec §FR-005]
- [ ] CHK022 - "Decrypted at runtime" in FR-005 qualified — at which boot stage must secret be available, behavior on decrypt fail? [Clarity, Spec §FR-005, Edge Case]
- [ ] CHK023 - "Cluster-agnostic k8s concerns" (FR-008) listed explicitly so implementers don't infer module split boundary? [Clarity, Spec §FR-008]
- [x] CHK024 - PS1 prompt format specified in reqs, or only implied by US-4 + plan? [Clarity, Gap — plan §PS1 Prompt Design has it, spec did not] — FR-014 now says "shell prompt (PS1) MUST match `silicon` system's styled prompt, adapted for cluster username (`bob`) and node hostname." Addressed.
- [x] CHK025 - US-4 quantify "familiar, well-equipped shell" via specific tools/config behaviors? [Clarity, Spec §US-4] — FR-014 quantifies: curated CLI utilities (with examples), bash/zsh config, `syshelp`, markdown reference doc, PS1 req, git inclusion. US-4 defers to FR-014. Addressed.
- [x] CHK026 - "Consistent bash/zsh config" in FR-014 defined — canonical shell, consistency reqs? [Clarity, Spec §FR-014] — Addressed: bash canonical. No zsh req for cluster nodes.

---

## Requirement Consistency

- [ ] CHK027 - Longhorn deferral (local-path provisioner first, plan Phase C) conflict with FR-012 + FR-004 reqs? Phased deferral captured in spec? [Consistency, Conflict — Spec §FR-004/FR-012 vs plan §Phase C]
- [x] CHK028 - FR-013 user reqs consistent with US-4 — US-4 says `bob` for HLC; risk desktop user (`eaglerock`) applied to cluster via module composition? [Consistency, Spec §FR-013 vs §US-4] — FR-013 = parameterized module by username; each system class (`hlc`, `desktop`, `ecto1`) maps to distinct username. Composition needs explicit import with correct param; cross-app needs wrong explicit config. Consistent. Addressed.
- [x] CHK029 - FR-011 (SSH only, password auth off) align with FR-002 provisioning flow? How does nixos-anywhere auth before SSH host keys + `bob` exist? [Consistency, Spec §FR-002 vs §FR-011] — Addressed: bob + SSH keys established by nixos-anywhere during provisioning; baseline OS gives initial SSH access.
- [x] CHK030 - SC-004 ("at most 2 new files, no changes to existing") consistent with flake.nix wiring (unavoidably adds `nixosConfiguration` entry)? [Consistency, Spec §SC-004] — Addressed: flake.nix wiring accepted exception; current pattern (host config file + flake.nix entry) satisfies SC-004 intent.
- [ ] CHK031 - SC-007 (dry-run no network beyond binary caches) account for sops-nix decryption, which needs node SSH host key? [Consistency, Spec §SC-007]
- [x] CHK032 - "Cluster node: `bob`" in FR-013 consistent with US-4 AS-1 (operator SSHs as `bob`, sees HLC MOTD)? Redundant or different aspects? [Consistency, Spec §FR-013 vs §US-4-AS-1] — Consistent + complementary: FR-013 defines user provisioning req (parameterized module), US-4 AS-1 defines end-to-end operator experience. No conflict. Addressed.

---

## Acceptance Criteria Quality

- [ ] CHK033 - SC-001 (12 nodes provisioned <4hr) measurable given SD flash time excluded — operator wait vs total wall-clock defined? [Measurability, Spec §SC-001]
- [ ] CHK034 - SC-002 (all nodes Ready <15min after last provisioned) measurable with clear start — when is "last node provisioned" complete? [Measurability, Spec §SC-002]
- [ ] CHK035 - SC-003 ("fully operational" after 1 node fail) define "fully operational" — no degraded storage, no API server impact, or no cluster downtime? [Clarity, Spec §SC-003]
- [ ] CHK036 - SC-005 (rolling update keeps ≥2 healthy servers) testable without live cluster — dry-run/sim path defined? [Measurability, Spec §SC-005]
- [ ] CHK037 - SC-006 ("unreadable in plaintext") have verification method — `git grep` scan, sops validation, CI check? [Measurability, Spec §SC-006]
- [ ] CHK038 - Acceptance criteria for `syshelp` — exit 0, paged output, fixed category set? [Completeness, Gap]

---

## Scenario Coverage

- [ ] CHK039 - Reqs for Pi fail-to-boot from USB RAID post-provision — operator recover without full reprovision? [Coverage, Edge Case §1]
- [ ] CHK040 - Req for `nixos-anywhere` losing SSH mid-install — retry from scratch, partial recovery, idempotent re-run? [Coverage, Spec §Edge Cases §4]
- [ ] CHK041 - Reqs for k3s token-absent — node fail clean, log specific error, retry? [Coverage, Spec §Edge Cases §5]
- [ ] CHK042 - Spec define DNS cutover reqs — traffic drain, health-check gate, rollback criteria? [Coverage, Spec §Edge Cases §6]
- [ ] CHK043 - Rolling update reqs for mid-update node fail + abort — stop-on-failure required? [Coverage, Gap]
- [ ] CHK044 - Reqs for ArgoCD bootstrap fail — acceptable cluster state if bootstrap fails partway through one-time apply? [Coverage, Gap]

---

## Edge Case Coverage

- [ ] CHK045 - Req for mdadm RAID1 degraded behavior — NixOS boots normally with one failed USB drive, operator notify required? [Edge Case, Spec §Edge Cases §1]
- [ ] CHK046 - Spec define Pi5 NVMe-not-detected — provisioning abort, continue without NVMe, config error? [Edge Case, Spec §Edge Cases §2]
- [ ] CHK047 - Reqs for updating `hlc-401` (init server with `clusterInit=true`) during rolling update — mandatory sequence/quorum check before update? [Edge Case, Spec §US-5, data-model §Rolling Update Sequence]
- [ ] CHK048 - Req for duplicate `clusterInit=true` protection — research R-004 notes split-brain; config check or CI gate required by spec? [Edge Case, Spec §FR-006]
- [ ] CHK049 - Reqs for Longhorn PV behavior on Pi5 worker decommission — data migration, replica rebalance, runbook? [Edge Case, Gap]

---

## Non-Functional Requirements

- [ ] CHK050 - Build-time perf reqs specified — image build <X min on gibson — or unbounded? [Performance, Gap]
- [ ] CHK051 - Security req for acceptable SSH host key types (`ed25519` only, or `rsa` too)? [Security, Spec §FR-005]
- [ ] CHK052 - Req for secret rotation cadence — k3s token rotate frequency, rotation procedure without full cluster reset? [Security, Gap — Spec §Assumptions §4 says token doesn't change post-create, assumption not req]
- [ ] CHK053 - Observability reqs — nodes expose metrics (node-exporter), in scope for Phase A or later? [Non-Functional, Gap]
- [ ] CHK054 - Log retention or centralized logging req for cluster nodes? [Non-Functional, Gap]

---

## Dependencies & Assumptions

- [ ] CHK055 - `raspberry-pi-nix` (archived March 2025) dep documented in spec as risk with explicit fallback reqs, or only in research.md? [Dependency, Gap — research.md §R-001 covers, spec does not]
- [ ] CHK056 - QEMU aarch64 emulation on gibson assumption documented as operator prereq, or could someone build without it? [Assumption, Spec §Assumptions §1]
- [ ] CHK057 - Unifi network dep (Assumption §2) validated — DHCP reservation + VLAN reqs followable by implementer? [Dependency, Spec §Assumptions §2, Gap]
- [ ] CHK058 - "Existing Debian cluster keeps running" assumption have matching req for min overlap period or cutover gate criteria? [Assumption, Spec §Assumptions §3]
- [ ] CHK059 - Pi5 NVMe drives unformatted pre-provisioning assumption documented as pre-provision check or req? [Assumption, Spec §Assumptions §9]

---

## Ambiguities & Conflicts

- [ ] CHK060 - Spec uses "Bob Ross quote" for HLC MOTD (US-4, FR-015) — fixed or rotating, and if rotating, quote source/pool a req? [Ambiguity, Spec §FR-015]
- [ ] CHK061 - FR-016 says shell utilities module "implemented first for HLC, then generalized" — delivery sequencing req with acceptance criteria, or impl guideline? [Ambiguity, Spec §FR-016]
- [ ] CHK062 - Spec lists "ArgoCD bootstrap = one-time manual `kubectl apply`" as assumption, but US-2 implies bootstrap manifest is a deliverable. Manifest in scope or out? [Conflict, Spec §US-2 vs §Assumptions §7]
- [ ] CHK063 - "No changes to existing files" in SC-004 apply to `flake.nix`? Adding `nixosConfiguration` entry unavoidable — accepted exception or SC-004 gap? [Ambiguity, Spec §SC-004]
- [x] CHK064 - PS1 prompt deliverable of FR-014 (shell env), or under FR-015 (MOTD/branding) or FR-016 (shell generalization)? Plan puts it in `modules/shell/prompt.nix` but no FR directly required PS1. [Gap — plan §PS1 Prompt Design had no matching FR] — FR-014 now owns PS1: "shell prompt (PS1) MUST match `silicon` system's styled prompt, adapted for cluster username (`bob`) and node hostname." Addressed.
- [ ] CHK065 - Colorization reqs for `syshelp` output specified — specific colors matching Gruvbox theme used elsewhere, or any color OK? [Clarity, Spec §FR-014]

---

## Notes (Requirements Quality Run)

- Check off done items: `[x]`
- Add findings inline after item text
- `[Gap]` = req missing, add to spec
- `[Ambiguity]` = req exists but underspecified
- `[Conflict]` = two reqs/artifacts inconsistent
- CHK001–CHK065 cover full spec (FR-001–FR-016, edge cases, assumptions, success criteria)