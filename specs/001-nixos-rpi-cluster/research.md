# Research: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Date**: 2026-04-25

## R-001: raspberry-pi-nix

**Decision**: Use with caution — archived March 2025, may need fork for NixOS 25.11.

**Rationale**: Flake imports `raspberry-pi-nix`, existing `hlc-501` config works. Module supports `bcm2711` (Pi4) and `bcm2712` (Pi5), exports `nixosModules.raspberry-pi` and `nixosModules.sd-image`, handles firmware/kernel per board. Repo archived 2025-03-23, no named successor.

**Alternatives considered**:
- `nvmd/nixos-raspberrypi` — referenced in PREP.md for installer images, different project
- `saronic-technologies/rpi-nix` — org fork, may be maintained
- Manual kernel/firmware config — too much maintenance

**Risks**:
- No NixOS 25.11 compat testing by maintainers
- Pi5 USB/NVMe u-boot boot non-functional (SD only)
- 84 forks; evaluate `saronic-technologies/rpi-nix` or pin to last known-good commit
- May need fork + maintain for cluster lifetime

**Action items**:
- Test current pin against NixOS 25.11 before building all 12 host configs
- Evaluate active forks if pin breaks
- Document chosen pin/fork in flake.nix comments

---

## R-002: disko (disk layout)

**Decision**: Use disko — mature, mdadm RAID1 first-class.

**Rationale**: disko has `example/mdadm.nix` and `example/boot-raid1.nix` matching our use case: separate FAT32 `/boot` + ext4 root on mdadm RAID1. Multi-device configs (SD + 2× USB) supported, no device coupling.

**Alternatives considered**:
- Manual partitioning scripts — imperative, violates Constitution Principle I
- NixOS `fileSystems` only — no initial partitioning for nixos-anywhere

**Risks**:
- aarch64 test coverage thinner than x86_64 in examples
- SD FAT32 + USB mdadm split unusual — test before scale provisioning
- mdadm UUID stability across reboots needs `boot.initrd.mdadmConf` — verify disko generates
- USB device paths (`/dev/sda`, `/dev/sdb`) may not be stable — consider `by-id` paths

**Action items**:
- Write disko configs using `by-id` paths where possible
- Test disko config on single Pi4 + Pi5 before all-node rollout
- Verify mdadm array reassembles after reboot

---

## R-003: nixos-anywhere (remote provisioning)

**Decision**: Use nixos-anywhere with custom aarch64 kexec image.

**Rationale**: nixos-anywhere integrates with disko for declarative remote provisioning. aarch64-linux supported via custom kexec image.

**Command for aarch64 targets**:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --kexec "$(nix build --print-out-paths \
    github:nix-community/nixos-images#packages.aarch64-linux.kexec-installer-nixos-unstable-noninteractive \
  )/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz" \
  --flake '.#<hostname>' \
  root@<ip>
```

**Alternatives considered**:
- Manual `nixos-install` via SSH — imperative, error-prone at scale
- Custom install scripts — reinventing wheel

**Risks**:
- kexec image from nixos-unstable channel (installer env only — installed env uses 25.11 stable)
- Target Pi must run Linux with kexec (SD card NixOS image satisfies)
- Cross-compile from x86_64 needs QEMU emulation (`boot.binfmt.emulatedSystems`) or native aarch64 builder
- QEMU slow; consider provisioned Pi as remote builder for later deploys

**Action items**:
- Enable `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on gibson (build host)
- Pre-build kexec image once, cache locally
- Provision hlc-401 first, optionally register as remote builder for remaining nodes

---

## R-004: k3s on NixOS

**Decision**: Use upstream NixOS `services.k3s` module — all required options exist natively.

**Rationale**: Module exposes `role`, `tokenFile`, `clusterInit`, `serverAddr`, `extraFlags`. HA embedded etcd works with `clusterInit = true` on one bootstrap server.

**Key configuration details**:
- Use `tokenFile` (not `token`) to avoid exposing secret in nix store
- Cgroup kernel params required for RPi: `"cgroup_memory=1" "cgroup_enable=memory" "cgroup_enable=cpuset"`
- Firewall ports: TCP 6443 (API), 2379-2380 (etcd), 10250 (kubelet); UDP 8472 (Flannel VXLAN), 51820 (WireGuard)
- `clusterInit` migration from sqlite to etcd one-way — plan from start

**Alternatives considered**: None — `services.k3s` canonical NixOS module.

**Risks**:
- k3s systemd unit depends on `firewall.service` — ensure firewall module loads first
- `clusterInit = true` must be set on exactly one node; multiple causes split-brain
- `extraFlags` needed for non-default options (e.g., `--flannel-backend=wireguard-native`)

**Action items**:
- Set cgroup params in both `rpi4.nix` and `rpi5.nix`
- Add TCP 10250 (kubelet) to firewall ports (missing from informal plan)
- Document cluster reset procedure for token rotation

---

## R-005: sops-nix (secrets management)

**Decision**: Use `sops.age.sshKeyPaths` with single `secrets/hlc.yaml` for all 12 nodes.

**Rationale**: sops-nix derives age keys from SSH host ed25519 keys at activation — no separate age key per node. Single YAML with multi-recipient encryption works for shared k3s token.

**`.sops.yaml` pattern**:
```yaml
keys:
  - &admin age1<admin-pubkey>
  - &hlc401 age1<hlc-401-host-pubkey>
  # ... all 12 nodes
creation_rules:
  - path_regex: secrets/hlc\.yaml$
    key_groups:
    - age:
      - *admin
      - *hlc401
      # ... all recipients in ONE key_groups entry
```

**Critical**: Do NOT put `-` before `age:` within `key_groups` entry — triggers Shamir secret sharing requiring multiple keys to decrypt.

**Alternatives considered**:
- agenix — similar approach, less ecosystem support
- Vault — overkill for home lab cluster

**Risks**:
- SSH host key must exist before first deploy — SD boot generates, nixos-anywhere preserves
- `sops updatekeys` needs decryption access — admin key must always be in recipients
- Adding node requires re-encryption: update `.sops.yaml`, run `sops updatekeys`

**Action items**:
- Generate admin age key on gibson before first provision
- Collect host ed25519 pubkeys during SD first-boot phase
- Convert host SSH keys to age pubkeys: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`

---

## R-006: Longhorn on NixOS

**Decision**: HIGH RISK — Longhorn on NixOS actively broken upstream. Plan alternatives.

**Rationale**: Longhorn containers use `nsenter` to resolve binaries (`mount`, `iscsiadm`) via FHS paths missing on NixOS. `ghcr.io/duckfullstop/nixos-longhorn-manager` image targets Longhorn v1.1.0 (2021), explicitly abandoned by author. Upstream issue #2166 in "Icebox" since 2021, no fix shipped.

**Required host prerequisites** (regardless of Longhorn compat):
- `services.openiscsi.enable = true`
- Kernel modules: `iscsi_tcp`, `dm_crypt`, `nfs`
- `environment.systemPackages`: `nfs-utils`, `cryptsetup`

**Alternatives considered**:
- **OpenEBS (jiva/cStor)**: Working NixOS deployments documented in community configs
- **democratic-csi with NAS backend**: Works on NixOS, needs external NAS
- **Rook-Ceph**: Heavy for RPi hardware, NixOS-compatible
- **Local-path provisioner**: Simplest, no replication, ships with k3s
- **Custom Longhorn images**: Build NixOS-patched per release — ongoing maintenance

**Risks**:
- No maintained NixOS-compat Longhorn images for 1.5+
- Custom images = ongoing maintenance per Longhorn release
- `allowPrivileged = true` required in k3s config regardless of storage solution

**Action items**:
- Implement `modules/k8s/longhorn.nix` with host prerequisites (kernel modules, open-iscsi)
- Start with k3s local-path provisioner for initial cluster validation
- Evaluate OpenEBS or custom Longhorn images as follow-up
- Keep Longhorn prerequisites in module even if deployment uses alternative
- Document NixOS compat issue in spec for future reference

---

## R-007: Parameterized MOTD Module

**Decision**: Use `environment.etc."motd".text` with NixOS module options.

**Rationale**: `environment.etc."motd".text` writes `/etc/motd`, SSH and PAM display on login. Nix string interpolation with `config.networking.hostName` works at eval time. No systemd service needed.

**Alternatives considered**:
- `programs.bash.loginShellInit` — fires on subshells, not just login
- Systemd service writing `/etc/motd` at boot — unnecessary complexity
- Static file — not parameterizable

**Implementation pattern**:
```nix
options.cluster.motd = {
  enable = mkEnableOption "cluster MOTD";
  clusterName = mkOption { type = types.str; };
  asciiArt = mkOption { type = types.lines; default = ""; };
  tagline = mkOption { type = types.str; default = ""; };
  attribution = mkOption { type = types.str; default = ""; };
};
config = mkIf cfg.enable {
  environment.etc."motd".text = ''
    ${cfg.asciiArt}
    Cluster node: ${config.networking.hostName}
    ${optionalString (cfg.tagline != "") cfg.tagline}
    ${optionalString (cfg.attribution != "") cfg.attribution}
  '';
};
```

---

## R-008: Shared Shell Utilities + syshelp

**Decision**: Dedicated module with `pkgs.writeShellScriptBin` for `syshelp`.

**Rationale**: `writeShellScriptBin` puts script in Nix store, symlinks into PATH — canonical NixOS approach. Avoid `shellAliases` (don't work in scripts/non-interactive shells).

**Action items**:
- Create `modules/shell/utilities.nix` with curated package list + syshelp script
- Keep lean — shared by all systems; desktop/k8s tools in separate modules
- Generate markdown reference doc alongside module

---

## R-009: Parameterized User Module

**Decision**: NixOS module with `lib.mkOption` for username, wiring home-manager dynamically.

**Rationale**: `users.users.${cfg.username}` works because Nix evaluates option before building attrset. Same pattern for `home-manager.users.${cfg.username}`.

**Gotchas**:
- Avoid `mkMerge`/conditional logic on username — prevents infinite recursion
- Keep option in `options`, consume only in `config`
- Replace inline user defs in existing host configs (e.g., `hlc-501`)

---

## R-010: raspberry-pi-nix + nixos-hardware NixOS 25.11 Compatibility

**Finding**: Two conflicts during Phase A dry-run validation (2026-04-25).

**Issue 1 — Pi4 bootloader conflict**:
`nixos-hardware.nixosModules.raspberry-pi-4` sets `boot.loader.generic-extlinux-compatible.enable = true`, conflicts with `raspberry-pi-nix` u-boot bootloader which requires `false`.
**Fix**: Added `boot.loader.generic-extlinux-compatible.enable = lib.mkForce false` in `modules/hardware/rpi4.nix`.

**Issue 2 — Pi5 dtmerge option missing**:
`hardware.raspberry-pi."5".apply-overlays-dtmerge.enable` not present at pinned `nixos-hardware` commit (`2096f3f`). Option introduced later.
**Fix**: Removed option from `modules/hardware/rpi5.nix` for Phase A. Re-enable in Phase B when configuring NVMe/PCIe for Longhorn — flake.lock pin should be updated by then.

**Status**: All 12 hosts pass `nixos-rebuild dry-run` after both fixes.

---

## R-011: SSH Hang / PS1 Garble Root Cause

**Status**: Partially resolved (2026-04-26). SSH hang resolved; PS1 fix deferred to Phase C.

**Original symptom (prior iteration)**: hlc-501 accepted TCP/22 and key auth but interactive shell never reached usable prompt. hlc-508 went fully offline after config revert.

**Resolution (observed 2026-04-26)**: After reflashing with images built from commit `210af9b` (pre-imaging work), hlc-501 boots and accepts interactive SSH. Hang no longer reproducible. Suspected culprit: `services.openssh.settings` block (`ClientAliveInterval`, `MaxStartups`, `UseDns`) since removed.

**Additional finding (2026-04-26)**: hlc-504 passes smoke test. Reachable via alacritty on silicon (SSH'd through marks.dev VLAN). Not reachable from kitty on gibson — root cause: `TERM=xterm-kitty` not in NixOS default terminfo database. Workaround: use alacritty, or `TERM=xterm-256color ssh bob@<host>`. Known limitation (documented in spec Assumptions), not a Phase A bug.

**Remaining issue — PS1 garble**: `modules/shell/prompt.nix` has two interacting bugs:

1. Color variables use `\033` in Nix multi-line strings (`''...''`):
   ```nix
   reset = ''"\[\033[0m\]"'';  # \033 is NOT interpreted as ESC by bash PS1
   ```
   Bash PS1 processes `\e` as ESC but NOT `\033` (C-style octal). Escape byte never emitted; terminal sees `033[0m` as literal ASCII.

2. Color variable values include wrapping double-quotes (`".."`). When Nix interpolates into bash `promptInit` string, result is broken bash quoting.

**Fix (deferred to Phase C)**: In `modules/shell/prompt.nix`:
- Replace `\033[` with `\e[` in all color variable definitions.
- Remove wrapping double-quotes from color variable values.
- Example: `reset = ''\[\e[0m\]'';` (no outer quotes; `\e` renders as ESC in PS1).

**Deferral rationale**: Phase A0 strategy strips prompt.nix from host configs entirely, uses default bash prompt. PS1 module reintroduced Phase C after SSH connectivity verified stable across all nodes. Eliminates risk of PS1 bug causing another unreachable-node incident during baseline.

**hlc-401**: Unreachable during prior iteration. Triage in Phase A0, step 3. Probable causes: DHCP MAC mismatch, wrong board image (Pi4 vs Pi5), or hardware/SD issue.