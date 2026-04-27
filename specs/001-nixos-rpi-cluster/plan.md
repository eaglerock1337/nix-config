# Implementation Plan: NixOS RPi Cluster Foundation

**Branch**: `001-nixos-rpi-cluster` | **Date**: 2026-04-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-nixos-rpi-cluster/spec.md`

> **Plan revised 2026-04-26 (post-first-flash).** hlc-501 is booted and SSH-accessible;
> hlc-401 is unreachable. hlc-501's interactive shell shows garbled PS1 (ANSI escape
> sequences printed as literal text, not rendered as colors). Root cause: `prompt.nix`
> uses `\033` octal in Nix multi-line strings and wraps color variables in double-quotes;
> bash PS1 interprets `\e` as ESC but NOT `\033`, so escape codes render literally.
>
> Priorities per operator feedback (2026-04-26 clarification session):
> 1. Usable PS1 matching `silicon`'s styled prompt, adapted for `bob@<hostname>`.
> 2. Baseline POSIX shell environment (standard tools, clean interactive session).
> 3. On-device git update workflow (git pull + `nixos-rebuild switch` as fallback
>    to workstation-push `update-node` target).
>
> This revision promotes shell baseline to Phase A1 (was deferred to Phase C),
> adds on-device update path documentation, and scopes Makefile to
> build/provision/update only (no SSH login convenience targets).

## Summary

Get all 9 work-set HLC nodes (hlc-401, hlc-501–508) online, reliably SSH-accessible,
with a correctly rendered shell prompt that matches the `silicon` operator experience
adapted for `bob@<hostname>`. Validate both update paths — workstation push
(`nixos-rebuild --target-host`) as primary, on-device `git pull` + rebuild as fallback.
Defer disk layout (USB-RAID1), secrets (sops-nix), and cluster software (k3s, ArgoCD,
Longhorn) to later phases.

## Technical Context

**Language/Version**: Nix (flakes), NixOS 25.11 stable, aarch64-linux for Pi nodes;
build host gibson is x86_64-linux with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`.

**Primary Dependencies**: `nixpkgs/nixos-25.11`, `raspberry-pi-nix` (archived 2025-03;
pinned), `nixos-hardware` (Pi4/Pi5 modules), `home-manager` (silicon only).
`disko`, `sops-nix`, `nixos-anywhere` deferred to Phase D+.

**Storage**: SD card boot only for Phases A–C. USB-RAID1 root and Pi5 NVMe deferred.

**Testing**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
as pre-deploy gate. `make dry-run-all` for eval-only across all 12 (including
decommissioned-set dry-run check). Post-deploy smoke: `scripts/smoke-test.sh` —
ping, non-PTY ssh `true`, interactive PTY ssh reaching prompt within 10s.
`nixos-rebuild build-vm` for any change touching shell/prompt (where feasible on
aarch64 — verify VM boot works or use qemu-aarch64 wrapper).

**Target Platform**: 9 work-set nodes: 1× Pi4/bcm2711 (hlc-401), 8× Pi5/bcm2712
(hlc-501–508). Headless, rack-mounted, no console. Build host: gibson.
3 decommissioned-set nodes (hlc-402–404): Nix configs evaluate only; no flash/switch.

**Project Type**: NixOS configuration repo (flake-based).

**Constraints**:
- No console access. SSH must survive every change.
- Pre-deploy full build gate on canary before rolling to remaining nodes.
- Rollback via `nixos-rebuild switch --rollback --target-host` must work.
- On-device builds on Pi hardware are slow and RAM-constrained (4-8GB); tolerated
  as a fallback path only. Never required for routine cluster updates.
- Makefile targets: build-image, flash-image, dry-run, dry-run-all, build, update-node,
  update-cluster, smoke-test, canary-deploy, encrypt-secret. No SSH login targets.

**Known bug**: `modules/shell/prompt.nix` v1 uses `\033` (not interpreted as ESC in
bash PS1) and wraps color variables in double-quotes, producing garbled literal output.
Fix: replace `\033` with `\e` throughout, remove wrapping double-quotes from Nix
color variables (see Phase A1 step 1).

## Constitution Check

*GATE: Must pass before Phase 0. Re-check after Phase 1.*
*Aligned to constitution v1.1.0.*

| Principle | Status | Notes |
|---|---|---|
| I. Declarative Configuration | ✅ | All state in Nix. No imperative changes permitted. |
| II. Reproducibility via Flakes | ✅ | `flake.lock` pins every input. |
| III. Modular Design | ⚠️ deferred (legal under Principle V) | Host configs remain minimal (no shared modules) through Phase A. Shared modules (shell, prompt, utilities, MOTD, operator user) reintroduced one at a time in Phase B, each with canary gate. Logged in WORKAROUNDS.md as W-001; exit condition = Phase B complete. |
| IV. Safety-First Changes | ✅ | Canary deploy + smoke-test mandatory for every runtime change. Auto-rollback on smoke-test failure. |
| V. Pragmatic Phasing | ✅ | Phase A workarounds (passwordless wheel W-002, PasswordAuthentication default W-003, inline host configs W-001) all logged with exit conditions. |
| VI. Minimal & Explicit Footprint | ✅ | Phase A footprint minimal; packages alphabetically sorted when added. |
| Cluster Topology | ✅ | Work-set (9 nodes) vs decommissioned-set (3 nodes) correctly scoped throughout. |

**Result: PASS with one justified deferral (Principle III via Principle V).**

## Project Structure

### Documentation (this feature)

```text
specs/001-nixos-rpi-cluster/
├── plan.md              # This file
├── research.md          # Phase 0 artifacts — still valid for Phase D+ tech
├── data-model.md        # Node IPs/MACs/age keys reference
├── quickstart.md        # To be revised at Phase A2 step 7
├── contracts/           # N/A — internal config repo
├── checklists/
│   └── requirements.md  # Existing
└── tasks.md             # Regenerated by /speckit-tasks
```

### Source Code (repository root)

```text
flake.nix                       # nixosConfigurations for silicon + 12 HLC nodes
Makefile                        # build-image, flash-image, dry-run[-all], build,
                                #   update-node, update-cluster, smoke-test, canary-deploy
                                #   (NO ssh login targets — connect via ssh bob@<host>)

hosts/
├── silicon/                    # Unchanged
├── hlc-401/configuration.nix   # Pi4, minimal — gains shell modules in Phase B
├── hlc-402/configuration.nix   # Pi4, decommissioned-set — dry-run only
├── hlc-403/configuration.nix   # Pi4, decommissioned-set — dry-run only
├── hlc-404/configuration.nix   # Pi4, decommissioned-set — dry-run only
└── hlc-50{1-8}/configuration.nix  # Pi5 workers, minimal → shell modules in Phase B

modules/
├── home/                       # Unchanged silicon home-manager modules
├── hardware/
│   ├── rpi4.nix                # Pi4 board config (mkForce extlinux=false)
│   └── rpi5.nix                # Pi5 board config
├── shell/
│   ├── common.nix              # Bash history, aliases — tested in Phase B
│   ├── prompt.nix              # PS1 module — NEEDS BUG FIX before deploy (Phase A1)
│   └── utilities.nix           # sysadmin packages + syshelp script — Phase B
├── motd/default.nix            # Parameterized MOTD module — Phase C
├── cluster/hlc/motd.nix        # HLC-specific MOTD content — Phase C
└── users/operator.nix          # Parameterized user module — Phase B

scripts/
└── smoke-test.sh               # ping + non-PTY ssh + interactive PTY ssh check
```

**Structure Decision**: Phase A retains minimal inline host configs (no shared modules).
Module reintroduction in Phase B follows strict one-module-at-a-time canary discipline.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Principle III deferred for Phase A: work-set host configs inline minimal config instead of shared module | Prior attempt (Phase 0) bundled shared modules + 12 hosts; result was garbled PS1 and unreachable nodes. Minimal inline configs give zero inter-host blast radius and make regressions attributable to individual changes. Principle V explicitly authorizes this with WORKAROUNDS.md tracking. | The "correct" shared-module pattern is what we're iterating toward in Phase B; restoring it before the baseline is stable repeats the mistake. |
| `make canary` wraps `nixos-rebuild switch --target-host` with pre-build + smoke-test + auto-rollback | Headless Pi nodes cannot be recovered without physical access when SSH is broken. The canary wrapper auto-rollbacks a failed switch. | Plain `nixos-rebuild switch` is what was used when a node dropped off the network in the prior iteration. |

---

## Phases

### Phase A0 — Triage & PS1 fix

**Goal**: Resolve the two immediate blockers from the first flash:
1. hlc-401 unreachable.
2. PS1 on hlc-501 renders ANSI escape codes as literal text.

**A0.1 — Fix `prompt.nix` bug (workstation, no node required)**

The bug: `modules/shell/prompt.nix` sets color variables as Nix multi-line strings
with wrapping double-quotes and uses `\033` (which bash does not interpret in PS1).

Fix in `modules/shell/prompt.nix`:
- Remove wrapping double-quotes from color variable values.
- Replace `\033[` with `\e[` throughout (bash PS1 processes `\e` as ESC).
- Remove the double quotes from the `hostColor` option default.
- Verify the PS1 string in `promptInit` does not re-wrap the variables.

After edit, validate: `nixos-rebuild dry-run --flake .#hlc-501` must pass (eval check),
then `nix build .#nixosConfigurations.hlc-501.config.system.build.toplevel` (build check).
If `nixos-rebuild build-vm` works for aarch64 on gibson, also verify interactive login.

**A0.2 — Deploy fixed prompt to hlc-501 (canary)**

```
make canary HOST=hlc-501 IP=10.23.50.51
```

Canary sequence: full build → `nixos-rebuild switch --target-host` → smoke-test →
auto-rollback on failure. After smoke-test passes, manual interactive SSH check:
`ssh bob@hlc-501.marks.dev` — confirm PS1 matches silicon-style without literal
escape codes, `exit` returns cleanly.

If `make canary` target doesn't exist yet, add it in this step (it was specified
in the prior plan's A1 Makefile section and may already be present; check first).

**A0.3 — Triage hlc-401 unreachability**

Possible causes (check in order):
1. Wrong MAC in DHCP reservation — verify Unifi DHCP server shows the Pi4 MAC and
   it maps to `10.23.50.41`; check if Pi acquired a different IP.
2. Image build issue — confirm the Pi4 image was built from `bcm2711` board config;
   a Pi5 image flashed to a Pi4 would fail to boot.
3. Hardware/SD card issue — if the SD card write was incomplete, card may not boot.
4. Network port issue — confirm the Unifi switch port the Pi4 is on is active.

Recovery: if DHCP/boot, reflash with a freshly-built Pi4 SD image. Run `make build`
to verify the Pi4 image before flashing.

**A0 exit gate**: `make smoke-test HOST=hlc-501 IP=10.23.50.51` passes; hlc-401 is
reachable via ping and SSH.

---

### Phase A1 — Shell baseline across work-set

**Prerequisites**: A0 exit gate passes.

**Goal**: All 9 work-set nodes have the clean shell environment (common.nix + fixed
prompt.nix), verified by interactive SSH after each deployment.

The modules to add per node (inline imports added to each host configuration.nix):
- `modules/shell/common.nix` — bash history, aliases
- `modules/shell/prompt.nix` — silicon-style PS1

Deployment sequence (canary-first, one node at a time):
1. hlc-501 already done in A0. Confirm green.
2. hlc-401 — canary deploy, smoke-test, interactive SSH check.
3. hlc-502 through hlc-508 — roll out in pairs, smoke-test after each.

**Important**: each `hosts/hlc-NNN/configuration.nix` gains the two import lines.
This is still inline (no shared module wrapper) — Principle III still deferred.
The modules themselves are shared, but the import declaration duplicates across 9 files.

**PS1 style note**: The silicon prompt style that `prompt.nix` should target uses the
operator's home-manager bash config on `silicon`. Before implementing, SSH into silicon
and capture the exact PS1 format. If silicon's prompt is rendered via home-manager
dotfiles (not nix-managed), document the target format in `research.md` under a new
`R-012: Silicon PS1 style` entry, then implement the equivalent in `prompt.nix`.
The target: `bob@<hostname>` with the same visual structure silicon uses, adapted for
cluster username and node hostname. Color `\e[36m` (cyan) per the flashed image is
acceptable if it matches; verify against silicon.

**A1 exit gate**: All 9 work-set nodes pass `make smoke-test`; interactive SSH shows
correctly rendered colored PS1 on each.

---

### Phase A2 — Update path validation

**Prerequisites**: A1 exit gate passes.

**Goal**: Prove both update paths work for every node before layering more features.

**A2.1 — Workstation push path (primary)**

For one Pi4 (hlc-401) and one Pi5 (hlc-501):
1. Make a trivial config change (add a comment or bump a package).
2. `make canary HOST=<host> IP=<ip>` — forward deploy + smoke-test.
3. `nixos-rebuild switch --rollback --target-host bob@<host>` — rollback + smoke-test.
4. Forward deploy again to restore to current config.

Confirms `update-node` and `--rollback` both work reliably.

**A2.2 — On-device git fallback path (secondary)**

On hlc-501 (already has git from `prompt.nix`'s `environment.systemPackages`):
```bash
ssh bob@hlc-501.marks.dev
git clone <repo-url> /tmp/nix-config   # use HTTPS or SSH depending on network access
cd /tmp/nix-config
sudo nixos-rebuild switch --flake .#hlc-501
```

Expected behavior:
- Nix evaluation will run locally on the Pi (slow but tolerable for occasional use).
- A full build may OOM on Pi4 (4GB RAM) for large closures — if OOM occurs, document
  in `research.md` as `R-013: On-device rebuild RAM limits` and note that Pi5 (8GB)
  handles it; Pi4 on-device is for eval/dry-run only.
- This path is NOT used for routine updates. Document clearly in `quickstart.md`.

**A2.3 — Quickstart revision**

Rewrite `specs/001-nixos-rpi-cluster/quickstart.md` to reflect:
- Current (Phase A) reality: SD card flash → boot → smoke-test → canary → roll out.
- Workstation push as primary update path (`make update-node HOST=...`).
- On-device git fallback procedure with caveats (slow, Pi4 may OOM).
- Direct SSH: `ssh bob@<hostname>.marks.dev` (no Makefile target).

**A2 exit gate**: At least one Pi4 and one Pi5 complete forward + rollback canary
cycle; on-device rebuild attempted and result documented in `research.md`.

---

### Phase B — Static IPs + SSH host key inventory (no new modules)

**Prerequisites**: A2 exit gate passes.

**Goal**: Move from DHCP reservation to declared static IPs in Nix; inventory SSH
host pubkeys for future sops-nix age-recipient use.

Still inline (no shared module). Add `networking.interfaces.eth0.ipv4.addresses`,
`networking.defaultGateway`, `networking.nameservers` directly in each host config.
Canary on hlc-501 first, smoke-test, roll to remaining 8.

Collect `ssh_host_ed25519_key.pub` from each node during this phase and record in
`data-model.md` (SSH host key column, conversion to age pubkey via `ssh-to-age`).

**B exit gate**: All 9 nodes reachable on static IPs; host pubkeys in `data-model.md`.

---

### Phase C — Layered module reintroduction (one module at a time)

**Prerequisites**: B exit gate passes.

**Goal**: Reintroduce remaining modules (operator user, sysadmin utilities, MOTD)
using the proven canary-gate process. Retire Principle III deferral (W-001).

Module order (one canary cycle per module, hlc-501 as canary):
1. `modules/users/operator.nix` — parameterized `bob` user (without SSH hardening).
2. `modules/shell/utilities.nix` — sysadmin packages + `syshelp` command.
3. `modules/motd/default.nix` + `modules/cluster/hlc/motd.nix` — HLC MOTD banner.
4. SSH hardening — separate step, separate canary cycle.
5. ecto-1 stub modules — minimal placeholder (validates extensible structure).

After all five: remove Principle III deferral WORKAROUNDS entry W-001 (exit condition met).

**C exit gate per module**: all 9 work-set nodes pass smoke-test after rollout.
**C exit gate**: all modules deployed; `nixos-rebuild dry-run` succeeds for hlc-402,
hlc-403, hlc-404 (decommissioned-set config parity check).

---

### Phase D — Disko / USB-RAID1 root, sops-nix secrets

Deferred. Plan in detail at `/speckit-plan` time after C exits green.

### Phase E — k3s, ArgoCD, Longhorn

Deferred. Plan after Phase D. ArgoCD bootstrap is a one-time manual `kubectl apply`;
Longhorn NixOS compatibility documented in `research.md` R-006.

---

## Phase 0: Outline & Research

**Existing `research.md` is current** for Phase D+ (raspberry-pi-nix, disko,
nixos-anywhere, k3s, sops-nix, Longhorn). No new tech introduced in Phases A–C.

**New research items to add**:
- **R-011**: (in progress) SSH-hang root cause — update to reflect that hlc-501 is
  now accessible; the garbled PS1 is the remaining issue, root-caused to `prompt.nix`
  `\033` vs `\e` bug. Mark Open → Resolved in Phase A0.
- **R-012**: Silicon PS1 style — document the exact PS1 format/visual structure used
  on silicon (captured by SSHing into silicon during Phase A1 step 1).
- **R-013**: On-device rebuild RAM limits — document Pi4 vs Pi5 behavior during Phase A2.

**Output**: updated `research.md` entries (A0, A1, A2 tasks).

---

## Phase 1: Design & Contracts

**Data model**: `data-model.md` accurately reflects node topology, IPs, storage.
No structural changes needed. SSH host key column to be populated in Phase B.

**Contracts**: N/A — internal config repo.

**Quickstart**: Rewrite in Phase A2 step 3.

**Agent context**: CLAUDE.md already points to `specs/001-nixos-rpi-cluster/plan.md`.
No link change needed.

**Output**: `data-model.md` (SSH key column updated in Phase B), revised `quickstart.md`
(Phase A2), augmented `research.md` (Phases A0–A2).

---

## Stop and report

Plan complete. Run `/speckit-tasks` to regenerate `tasks.md` against this plan.
The existing `tasks.md` describes a prior phase structure and should be replaced.
