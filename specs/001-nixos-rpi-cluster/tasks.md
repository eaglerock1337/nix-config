# Tasks: NixOS RPi Cluster Foundation — Phase A (Nodes Online)

**Input**: Design documents from `specs/001-nixos-rpi-cluster/`
**Scope**: Phase A only — shared modules + flake wiring so all 12 hosts evaluate and can be
deployed/updated remotely over SSH. Stops before disko, sops-nix, k3s, and ArgoCD.

**Organization**: Tasks are grouped by user story. Phase A spans US1 (provisioning foundation)
and US4 (shell environment). US2, US3, US5 and plan Phases B–E are deferred.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependency)
- **[Story]**: Which user story this task belongs to
- All paths relative to repo root

---

## Phase 1: Setup (Repository Structure)

**Purpose**: Establish the new directory layout without touching existing configs.

- [x] T001 Create module directories: `modules/cluster/hlc/`, `modules/cluster/ecto1/`, `modules/k8s/`, `modules/storage/`, `modules/users/`, `modules/shell/`, `modules/motd/`
- [x] T002 Create host directories: `hosts/hlc-401/`, `hosts/hlc-402/`, `hosts/hlc-403/`, `hosts/hlc-404/`, `hosts/hlc-502/` through `hosts/hlc-508/` (hlc-501 already exists)
- [x] T003 Add `sops-nix` and `disko` inputs to `flake.nix` (inputs only — no nixosConfigurations yet); run `nix flake update` to lock

**Checkpoint**: Directory skeleton exists. `git status` shows new empty dirs and updated flake.lock.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared modules that every host config depends on. No host config can be written
until these exist.

**⚠️ CRITICAL**: All Phase 3–4 tasks depend on this phase being complete.

- [x] T004 Create `modules/hardware/rpi4.nix` — Pi4 board config: `raspberry-pi-nix.board = "bcm2711"`, cgroup kernel params (`cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset`), firmware settings; import `nixos-hardware.nixosModules.raspberry-pi-4` if available
- [x] T005 Create `modules/hardware/rpi5.nix` — Pi5 board config: `raspberry-pi-nix.board = "bcm2712"`, same cgroup params, import `nixos-hardware.nixosModules.raspberry-pi-5`; add `hardware.raspberry-pi."5".apply-overlays-dtmerge.enable = true` per nixos-hardware docs
- [x] T006 Create `modules/users/operator.nix` — parameterized NixOS module with options: `users.operator.username` (string), `users.operator.sshKeys` (list of strings), `users.operator.extraGroups` (list, default `["wheel"]`); config block sets `users.users.${cfg.username}` with `isNormalUser = true`, `openssh.authorizedKeys.keys`, groups; also sets `security.sudo.wheelNeedsPassword = false`
- [x] T007 Create `modules/motd/default.nix` — parameterized MOTD module with options: `cluster.motd.enable` (bool), `cluster.motd.clusterName` (str, default ""), `cluster.motd.asciiArt` (lines, default ""), `cluster.motd.tagline` (str, default ""), `cluster.motd.attribution` (str, default ""); config writes `environment.etc."motd".text` using `config.networking.hostName` interpolation

**Checkpoint**: `nix eval .#nixosModules` (or dry-run a test host) shows these modules load without errors.

---

## Phase 3: User Story 4 — Shell Environment (Priority: P3)

**Goal**: Every node the operator SSHs into has a consistent, well-equipped shell with the
correct PS1 prompt, MOTD, and curated sysadmin tools.

**Independent Test**: SSH into hlc-401 as `bob`; verify PS1 shows `[bob@hlc-401:~]$` in
green, MOTD shows HLC ASCII banner + Bob Ross quote + hostname, and `syshelp` lists tools.

- [x] T008 [US4] Create `modules/shell/common.nix` — bash defaults: `programs.bash.enable = true`; history size/ignoredups settings and common aliases (`ll`, `la`, `grep --color=auto`) via `programs.bash.interactiveShellInit` (NOT `shellInit` — must not pollute non-interactive script contexts); inputrc settings for arrow-key history search
- [x] T009 [P] [US4] Create `modules/shell/prompt.nix` — PS1 module with option `shell.prompt.hostColor` (ANSI escape code string, default green `\[\033[32m\]`); sets `programs.bash.promptInit` using a **single** `PROMPT_COMMAND` function that: (1) captures `$?` immediately as first line, (2) calls `__git_ps1` to populate `GIT_PS1` var, (3) sets PS1 to `[user@<colored-hostname>:~/path (git-branch)]$ ` with red color if exit code non-zero, normal color otherwise; root suffix `#`, user suffix `$`; add `pkgs.git` to `environment.systemPackages` for `__git_ps1`; do NOT assign `PROMPT_COMMAND` twice (second assignment silently drops git branch)
- [x] T010 [P] [US4] Create `modules/shell/utilities.nix` — `environment.systemPackages` with curated sysadmin tools (alphabetically sorted): `curl`, `dnsutils`, `ethtool`, `fd`, `file`, `git`, `htop`, `iotop`, `jq`, `lsof`, `mtr`, `ncdu`, `nmap`, `pciutils`, `ripgrep`, `tcpdump`, `tmux`, `tree`, `usbutils`, `wget`; plus `pkgs.writeShellScriptBin "syshelp"` that prints colorized categorized output (categories: Network, Storage, Process, Search, Data, Dev)
- [x] T011 [US4] Create `modules/cluster/hlc/motd.nix` — sets `cluster.motd.enable = true`, `cluster.motd.clusterName = "Happy Little Cloud"`, `cluster.motd.asciiArt` with the multi-line ASCII "HLC" banner art (replicate the existing Debian MOTD style), `cluster.motd.tagline` with a Bob Ross quote (fixed: "We don't make mistakes, just happy little accidents."), `cluster.motd.attribution = "~ Bob Ross"`
- [x] T012 [US4] Verify `modules/shell/utilities.nix` `syshelp` script: each tool category line must be colorized (ANSI bold for category header, plain for entries), each entry must include a one-line description, and the script must exit 0; test locally with `nix-instantiate --eval` or build a test package
- [x] T028 [P] [US4] Create `docs/syshelp-reference.md` — markdown reference doc required by FR-014; mirror the same categories and one-line descriptions used in the `syshelp` script (Network, Storage, Process, Search, Data, Dev); include a usage section and a note on adding tools; this doc is for onboarding context and stays in sync with `modules/shell/utilities.nix`

---

## Phase 4: User Story 1 — Nodes Online (Priority: P1)

**Goal**: All 12 host configs exist in the flake, evaluate cleanly, and can be deployed
over SSH with `nixos-rebuild switch --target-host`.

**Independent Test**: `for host in hlc-40{1..4} hlc-50{1..8}; do nixos-rebuild dry-run --flake .#$host; done` — all 12 pass.

### 4a: Refactor existing hlc-501

- [ ] T013 [US1] Refactor `hosts/hlc-501/configuration.nix` to use shared modules: remove inline `users.users.bob` block and replace with `users.operator.username = "bob"; users.operator.sshKeys = ["<key>"];`; import `modules/hardware/rpi5.nix`, `modules/users/operator.nix`, `modules/shell/common.nix`, `modules/shell/prompt.nix`, `modules/shell/utilities.nix`, `modules/motd/default.nix`, `modules/cluster/hlc/motd.nix`; set `shell.prompt.hostColor = "\[\033[36m\]"` (cyan — worker node); keep `raspberry-pi-nix.board`, `networking.hostName`, `networking.useDHCP`, `services.openssh.enable`, `system.stateVersion`; NOTE: `useDHCP = true` is intentional for Phase A only — a DHCP reservation for hlc-501's MAC must exist in Unifi for stable remote access; Phase B will add static IP config

### 4b: Pi4 control-plane host configs (parallelizable)

- [ ] T014 [P] [US1] Create `hosts/hlc-401/configuration.nix` — thin config: import `modules/hardware/rpi4.nix` + all shared shell/user/motd modules; set `networking.hostName = "hlc-401"`, `networking.interfaces.eth0.ipv4.addresses = [{address="10.23.50.41"; prefixLength=24;}]`, `networking.defaultGateway = "10.23.50.1"`, `networking.nameservers = ["10.23.50.1"]`, `users.operator.username = "bob"`, `users.operator.sshKeys = ["<gibson-pubkey>"]`, `shell.prompt.hostColor = "\[\033[32m\]"` (green, server), `services.openssh.enable = true`, `system.stateVersion = "25.11"`
- [ ] T015 [P] [US1] Create `hosts/hlc-402/configuration.nix` — identical structure to hlc-401 with `networking.hostName = "hlc-402"`, IP `10.23.50.42`
- [ ] T016 [P] [US1] Create `hosts/hlc-403/configuration.nix` — `networking.hostName = "hlc-403"`, IP `10.23.50.43`
- [ ] T017 [P] [US1] Create `hosts/hlc-404/configuration.nix` — `networking.hostName = "hlc-404"`, IP `10.23.50.44`

### 4c: Pi5 worker host configs (parallelizable)

- [ ] T018 [P] [US1] Create `hosts/hlc-502/configuration.nix` — import `modules/hardware/rpi5.nix` + shared modules; `networking.hostName = "hlc-502"`, IP `10.23.50.52`, `users.operator.username = "bob"`, `shell.prompt.hostColor = "\[\033[36m\]"` (cyan, worker), `services.openssh.enable = true`, `system.stateVersion = "25.11"`
- [ ] T019 [P] [US1] Create `hosts/hlc-503/configuration.nix` — `networking.hostName = "hlc-503"`, IP `10.23.50.53`
- [ ] T020 [P] [US1] Create `hosts/hlc-504/configuration.nix` — `networking.hostName = "hlc-504"`, IP `10.23.50.54`
- [ ] T021 [P] [US1] Create `hosts/hlc-505/configuration.nix` — `networking.hostName = "hlc-505"`, IP `10.23.50.55`
- [ ] T022 [P] [US1] Create `hosts/hlc-506/configuration.nix` — `networking.hostName = "hlc-506"`, IP `10.23.50.56`
- [ ] T023 [P] [US1] Create `hosts/hlc-507/configuration.nix` — `networking.hostName = "hlc-507"`, IP `10.23.50.57`
- [ ] T024 [P] [US1] Create `hosts/hlc-508/configuration.nix` — `networking.hostName = "hlc-508"`, IP `10.23.50.58`

### 4d: Flake wiring

- [ ] T025 [US1] Update `flake.nix`: add helper using correct Nix path concatenation (NOT string interpolation): `let mkHlcNode = { hostname, system ? "aarch64-linux", extraModules ? [] }: nixpkgs.lib.nixosSystem { inherit system; specialArgs = { inherit inputs; }; modules = [ raspberry-pi-nix.nixosModules.raspberry-pi raspberry-pi-nix.nixosModules.sd-image (./hosts + "/${hostname}/configuration.nix") ] ++ extraModules; };` — note `./hosts + "/${hostname}/configuration.nix"` (path concat) NOT `./hosts/${hostname}/configuration.nix` (string, not a path, causes eval error); add `nixosConfigurations` entries for hlc-401 through hlc-404 (passing `extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ]`) and hlc-502 through hlc-508 (passing `extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ]`); update existing `hlc-501` entry to use the helper pattern
- [ ] T026 [US1] Add `Makefile` with the following targets: `dry-run HOST=` → `nixos-rebuild dry-run --flake .#$(HOST)`; `dry-run-all` → loop dry-run over all 12 hosts; `update-node HOST= IP=` → `nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo`; `build-image-rpi4` → `nix build .#nixosConfigurations.hlc-401.config.system.build.sdImage`; `build-image-rpi5` → `nix build .#nixosConfigurations.hlc-501.config.system.build.sdImage`; `flash-image MODEL= DEV=` → decompress and `dd` the built image to `$(DEV)` (use `zstdcat result/sd-image/*.img.zst | sudo dd of=$(DEV) bs=4M status=progress`); stub-only comments for `provision`, `update-cluster`, `encrypt-secret` targets with `# Phase B/C — not yet implemented` so FR-010 is visibly tracked

### 4e: Validation

- [ ] T027 [US1] Run `make dry-run-all` and fix any evaluation errors; document any `raspberry-pi-nix` compatibility issues with NixOS 25.11 in `specs/001-nixos-rpi-cluster/research.md` under a new R-010 entry

---

## Dependencies

```text
Phase 1 (T001–T003)
  └─► Phase 2 (T004–T007)
        ├─► Phase 3 (T008–T012)  [US4 — parallel after T006/T007]
        │     └─► Phase 4 (T013–T027) [US1 — host configs need shell modules]
        └─► Phase 4 (T013–T027)  [US1 — host configs need user/hardware modules]

Within Phase 4:
  T013 (refactor hlc-501) → independent, can start as soon as Phase 2 + Phase 3 complete
  T014–T024 (host configs) → [P] all independent of each other, need Phase 2+3
  T025 (flake wiring) → needs T013–T024 complete
  T026 (Makefile) → independent, can write alongside T014–T024
  T027 (validation) → needs T025
```

## Parallel Execution Examples

**After Phase 2 completes**, the following can run simultaneously:

```bash
# Terminal 1: Shell modules
# T008 → T009 (parallel with T010) → T011 → T012

# Terminal 2: Hardware modules (already done in Phase 2)
# T013 (refactor hlc-501)

# Terminals 3–6: Host configs (all T014–T024 are [P])
# hlc-401, hlc-402, hlc-403, hlc-404 in parallel
# hlc-502 through hlc-508 in parallel
```

## Implementation Strategy

**MVP** (minimum to SSH into a Pi with correct env):
→ T001 → T002 → T004/T005 → T006 → T007 → T008 → T009 → T011 → T013 → T025 (for hlc-501 only) → flash SD → SSH in

**Full Phase A** (all 12 hosts evaluating):
→ Complete all tasks T001–T028 in dependency order

## Scope Boundary

Tasks T001–T027 deliver **Phase A** only. The following are explicitly out of scope for this
task list and will be addressed in subsequent `/speckit-tasks` runs:

| Deferred | Plan Phase | Description |
|----------|-----------|-------------|
| disko RAID configs | Phase B | USB RAID1 provisioning layout |
| sops-nix secrets | Phase B | k3s token encryption |
| nixos-anywhere | Phase B | Unattended remote provisioning |
| k3s modules | Phase C | k3s server/agent cluster setup |
| Longhorn prereqs | Phase C | NVMe/open-iscsi for storage |
| ArgoCD bootstrap | Phase D | GitOps layer |
| ecto-1 stubs | Phase E | Extensibility validation |
