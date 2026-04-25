# Research: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Date**: 2026-04-25

## R-001: raspberry-pi-nix

**Decision**: Use with caution — archived March 2025, may need a fork for NixOS 25.11.

**Rationale**: The flake already imports `raspberry-pi-nix` and the existing `hlc-501`
config works. The module supports both `bcm2711` (Pi4) and `bcm2712` (Pi5), exports
`nixosModules.raspberry-pi` and `nixosModules.sd-image`, and handles firmware/kernel
per board. However, the repo was archived on 2025-03-23 with no named successor.

**Alternatives considered**:
- `nvmd/nixos-raspberrypi` — referenced in PREP.md for installer images, different project
- `saronic-technologies/rpi-nix` — organizational fork, may be maintained
- Manual kernel/firmware config — too much maintenance burden

**Risks**:
- No NixOS 25.11 compatibility testing by maintainers
- Pi5 USB/NVMe u-boot boot is non-functional (SD card boot only)
- 84 forks exist; evaluate `saronic-technologies/rpi-nix` or pin to last known-good commit
- May need to fork and maintain for the lifetime of this cluster

**Action items**:
- Test current pin against NixOS 25.11 before building all 12 host configs
- Evaluate active forks if current pin breaks
- Document chosen pin/fork in flake.nix comments

---

## R-002: disko (disk layout)

**Decision**: Use disko — mature, mdadm RAID1 is first-class.

**Rationale**: disko has `example/mdadm.nix` and `example/boot-raid1.nix` demonstrating
exactly our use case: separate FAT32 `/boot` + ext4 root on mdadm RAID1. Multi-device
configs (SD card + 2× USB) are supported with no coupling between devices.

**Alternatives considered**:
- Manual partitioning scripts — imperative, violates Constitution Principle I
- NixOS `fileSystems` only — doesn't handle initial partitioning for nixos-anywhere

**Risks**:
- aarch64 testing coverage is thinner than x86_64 in examples
- SD card FAT32 + USB mdadm is an unusual split — test before provisioning at scale
- mdadm UUID stability across reboots needs `boot.initrd.mdadmConf` — verify disko generates this
- USB device paths (`/dev/sda`, `/dev/sdb`) may not be stable across reboots — consider `by-id` paths

**Action items**:
- Write disko configs referencing `by-id` paths where possible
- Test disko config on a single Pi4 and Pi5 before rolling out to all nodes
- Verify mdadm array reassembles correctly after reboot

---

## R-003: nixos-anywhere (remote provisioning)

**Decision**: Use nixos-anywhere with custom aarch64 kexec image.

**Rationale**: nixos-anywhere integrates directly with disko for declarative remote
provisioning. aarch64-linux targets are supported via a custom kexec image.

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
- Custom install scripts — reinventing the wheel

**Risks**:
- kexec image is from nixos-unstable channel (installer env only — installed env uses 25.11 stable)
- Target Pi must already be running Linux with kexec support (the SD card NixOS image satisfies this)
- Cross-compilation from x86_64 requires QEMU emulation (`boot.binfmt.emulatedSystems`) or a native aarch64 builder
- QEMU emulation is slow; consider using a provisioned Pi as a remote builder for subsequent deployments

**Action items**:
- Enable `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on gibson (build host)
- Pre-build the kexec image once and cache it locally
- Provision hlc-401 first, then optionally register it as a remote builder for remaining nodes

---

## R-004: k3s on NixOS

**Decision**: Use the upstream NixOS `services.k3s` module — all required options exist natively.

**Rationale**: The module exposes `role`, `tokenFile`, `clusterInit`, `serverAddr`, and
`extraFlags`. HA embedded etcd works with `clusterInit = true` on one bootstrap server.

**Key configuration details**:
- Use `tokenFile` (not `token`) to avoid exposing the secret in the nix store
- Cgroup kernel params required for RPi: `"cgroup_memory=1" "cgroup_enable=memory" "cgroup_enable=cpuset"`
- Firewall ports: TCP 6443 (API), 2379-2380 (etcd), 10250 (kubelet); UDP 8472 (Flannel VXLAN), 51820 (WireGuard)
- `clusterInit` migration from sqlite to etcd is one-way — plan from the start

**Alternatives considered**: None — `services.k3s` is the canonical NixOS module.

**Risks**:
- k3s systemd unit depends on `firewall.service` — ensure firewall module loads first
- `clusterInit = true` must be set on exactly one node; setting it on multiple causes split-brain
- `extraFlags` needed for non-default options (e.g., `--flannel-backend=wireguard-native`)

**Action items**:
- Set cgroup params in both `rpi4.nix` and `rpi5.nix`
- Add TCP 10250 (kubelet) to firewall ports (missing from informal plan)
- Document cluster reset procedure for token rotation

---

## R-005: sops-nix (secrets management)

**Decision**: Use `sops.age.sshKeyPaths` with a single `secrets/hlc.yaml` for all 12 nodes.

**Rationale**: sops-nix derives age keys from SSH host ed25519 keys at activation time —
no separate age key management per node. A single YAML file with multi-recipient
encryption works for the shared k3s token.

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

**Critical**: Do NOT put `-` before `age:` within a `key_groups` entry — that triggers
Shamir secret sharing requiring multiple keys to decrypt.

**Alternatives considered**:
- agenix — similar approach, less ecosystem support
- Vault — overkill for a home lab cluster

**Risks**:
- SSH host key must exist before first deploy — SD card boot generates it, nixos-anywhere preserves it
- `sops updatekeys` requires decryption access — admin key must always be in recipients
- Adding a node requires re-encryption: update `.sops.yaml`, run `sops updatekeys`

**Action items**:
- Generate admin age key on gibson before first provision
- Collect host ed25519 public keys during SD card first-boot phase
- Convert host SSH keys to age public keys: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`

---

## R-006: Longhorn on NixOS

**Decision**: HIGH RISK — Longhorn on NixOS is actively broken upstream. Plan for alternatives.

**Rationale**: Longhorn containers use `nsenter` to resolve binaries (`mount`, `iscsiadm`)
via FHS paths that don't exist on NixOS. The `ghcr.io/duckfullstop/nixos-longhorn-manager`
image targets Longhorn v1.1.0 (2021) and is explicitly abandoned by the author.
Upstream issue #2166 has been in "Icebox" since 2021 with no fix shipped.

**Required host prerequisites** (regardless of Longhorn compatibility):
- `services.openiscsi.enable = true`
- Kernel modules: `iscsi_tcp`, `dm_crypt`, `nfs`
- `environment.systemPackages`: `nfs-utils`, `cryptsetup`

**Alternatives considered**:
- **OpenEBS (jiva/cStor)**: Working NixOS deployments documented in community configs
- **democratic-csi with NAS backend**: Works on NixOS, requires external NAS
- **Rook-Ceph**: Heavy for RPi hardware, but NixOS-compatible
- **Local-path provisioner**: Simplest, no replication, ships with k3s
- **Custom Longhorn images**: Build NixOS-patched images per release — ongoing maintenance burden

**Risks**:
- No maintained NixOS-compatible Longhorn images for versions 1.5+
- Building custom images is an ongoing maintenance burden per Longhorn release
- `allowPrivileged = true` required in k3s config regardless of storage solution

**Action items**:
- Implement `modules/k8s/longhorn.nix` with host prerequisites (kernel modules, open-iscsi)
- Start with k3s local-path provisioner for initial cluster validation
- Evaluate OpenEBS or custom Longhorn images as a follow-up task
- Keep Longhorn prerequisites in the module even if the actual deployment uses an alternative
- Document the NixOS compatibility issue in the spec for future reference

---

## R-007: Parameterized MOTD Module

**Decision**: Use `environment.etc."motd".text` with NixOS module options.

**Rationale**: `environment.etc."motd".text` writes to `/etc/motd`, which SSH and PAM
display automatically on login. Nix string interpolation with `config.networking.hostName`
works at eval time. No systemd service needed.

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

**Rationale**: `writeShellScriptBin` puts the script in the Nix store and symlinks into
PATH — the canonical NixOS approach. Avoid `shellAliases` (don't work in scripts/non-interactive shells).

**Action items**:
- Create `modules/shell/utilities.nix` with curated package list + syshelp script
- Keep lean — shared by all systems; desktop/k8s tools go in separate modules
- Generate markdown reference doc alongside the module

---

## R-009: Parameterized User Module

**Decision**: NixOS module with `lib.mkOption` for username, wiring home-manager dynamically.

**Rationale**: `users.users.${cfg.username}` works because Nix evaluates the option before
building the attrset. Same pattern for `home-manager.users.${cfg.username}`.

**Gotchas**:
- Avoid `mkMerge`/conditional logic on the username to prevent infinite recursion
- Keep option in `options`, consume only in `config`
- Replace inline user definitions in existing host configs (e.g., `hlc-501`)

---

## R-010: raspberry-pi-nix + nixos-hardware NixOS 25.11 Compatibility

**Finding**: Two conflicts encountered during Phase A dry-run validation (2026-04-25).

**Issue 1 — Pi4 bootloader conflict**:
`nixos-hardware.nixosModules.raspberry-pi-4` sets `boot.loader.generic-extlinux-compatible.enable = true`,
conflicting with `raspberry-pi-nix`'s u-boot bootloader which requires it `false`.
**Fix**: Added `boot.loader.generic-extlinux-compatible.enable = lib.mkForce false` in `modules/hardware/rpi4.nix`.

**Issue 2 — Pi5 dtmerge option missing**:
`hardware.raspberry-pi."5".apply-overlays-dtmerge.enable` does not exist at the pinned
`nixos-hardware` commit (`2096f3f`). The option was introduced later.
**Fix**: Removed the option from `modules/hardware/rpi5.nix` for Phase A. Re-enable in Phase B
when configuring NVMe/PCIe for Longhorn — by then the flake.lock pin should be updated.

**Status**: All 12 hosts pass `nixos-rebuild dry-run` after both fixes.
