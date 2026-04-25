# Quickstart: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Date**: 2026-04-25

## Prerequisites

- **Build host**: gibson (Ryzen 9 5950X, NixOS) with:
  - `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` enabled
  - Admin age key generated: `age-keygen -o ~/.config/sops/age/keys.txt`
- **Hardware per node (Pi4 control plane)**:
  - Raspberry Pi 4, MicroSD card, 2× 64GB USB 3.2 drives (RAID1 root)
- **Hardware per node (Pi5 worker)**:
  - Raspberry Pi 5, MicroSD card, 2× 64GB USB 3.2 drives (RAID1 root), 1× Corsair MP600 Micro 1TB NVMe (Longhorn PVs)
- **Network**: Unifi-managed subnet at `10.23.50.0/24` with DHCP reservations per data-model

## Phase A: Get Nodes Online (Minimal Sync Path)

This is the fastest path to having NixOS nodes you can `nixos-rebuild switch` over SSH.

### 1. Clone and switch to feature branch

```bash
git clone <repo-url> && cd nix-config
git checkout 001-nixos-rpi-cluster
```

### 2. Build SD card images

```bash
# One image per Pi model — takes a while with QEMU emulation
make build-image-rpi4
make build-image-rpi5
```

### 3. Flash and boot

```bash
# Flash to MicroSD (adjust /dev/sdX)
make flash-image MODEL=rpi4 DEV=/dev/sdX
# Insert SD card, power on Pi, wait for DHCP lease
```

### 4. Verify SSH access

```bash
ssh bob@10.23.50.41    # hlc-401 (first control node)
# Should see HLC ASCII MOTD, PS1 prompt: [bob@hlc-401:~]$
```

### 5. Iterate configuration remotely

```bash
# From gibson, after editing modules:
nixos-rebuild dry-run --flake .#hlc-401 --target-host bob@10.23.50.41 --use-remote-sudo
nixos-rebuild switch --flake .#hlc-401 --target-host bob@10.23.50.41 --use-remote-sudo
```

### 6. Validate all hosts evaluate

```bash
# Dry-run all 12 hosts (no network needed, just evaluates the config)
for host in hlc-40{1..4} hlc-50{1..8}; do
  echo "--- $host ---"
  nixos-rebuild dry-run --flake .#$host 2>&1 | tail -1
done
```

## Phase B: Full Provisioning (After Phase A works)

### 7. Provision to USB RAID

```bash
# Provision single node via nixos-anywhere (installs to USB RAID1)
make provision HOST=hlc-401 IP=10.23.50.41
# Node reboots to USB RAID root filesystem
```

### 8. Collect host keys and set up secrets

```bash
# After each node boots from RAID:
ssh-keyscan -t ed25519 10.23.50.41 | ssh-to-age >> .sops.yaml
# Re-encrypt secrets with new recipients:
sops updatekeys secrets/hlc.yaml
```

### 9. Rebuild with secrets

```bash
make update-node HOST=hlc-401
# Node now has decrypted k3s token at /run/secrets/k3s-token
```

## Phase C: Cluster Bring-Up

### 10. Start k3s cluster

```bash
# Provision in order:
# 1. hlc-401 (init server, bootstraps etcd)
# 2. hlc-402, hlc-403, hlc-404 (join etcd)
# 3. hlc-501 through hlc-508 (join as agents)
make update-cluster
```

### 11. Verify cluster

```bash
ssh bob@10.23.50.41
kubectl get nodes    # All 12 should show Ready
```

## Adding a New Host

```bash
# 1. Create host directory
mkdir -p hosts/hlc-NEW
# 2. Create thin configuration.nix importing shared modules
# 3. Add nixosConfiguration to flake.nix
# 4. Dry-run: nixos-rebuild dry-run --flake .#hlc-NEW
# No existing files need modification.
```

## Key Make Targets

| Target | Description |
|--------|-------------|
| `make build-image-rpi4` | Build Pi4 SD card image |
| `make build-image-rpi5` | Build Pi5 SD card image |
| `make flash-image MODEL=rpi4 DEV=/dev/sdX` | Flash image to MicroSD |
| `make provision HOST=hlc-401 IP=10.23.50.41` | nixos-anywhere provisioning |
| `make update-node HOST=hlc-401` | Rebuild single node |
| `make update-cluster` | Rolling update all nodes |
| `make encrypt-secret` | Re-encrypt secrets after key changes |
| `make dry-run HOST=hlc-401` | Dry-run for single host |
| `make dry-run-all` | Dry-run all hosts |

## Useful Shell Commands (available on all nodes)

| Command | Description |
|---------|-------------|
| `syshelp` | Print categorized list of installed sysadmin tools |
| `kubectl get nodes` | Check cluster node status (server nodes only) |
