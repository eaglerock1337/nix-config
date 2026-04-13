# nixy-boi Memory

## Project Context

- **Owner**: Peter Marks (eaglerock)
- **Laptop**: silicon (ThinkPad X1 Carbon)
- **Cluster**: Happy Little Cloud (hlc)

## Cluster Architecture

### Node Naming Convention
- Format: `hlc-<pi-version><node-number>`
- Domain: `.marks.dev`
- Examples: hlc-401.marks.dev, hlc-508.marks.dev

### Nodes

**Control Plane (RPi4s):**
| Hostname | IP | Role |
|----------|-----|------|
| hlc-401 | 10.23.50.41 | Control plane (init) |
| hlc-402 | 10.23.50.42 | Control plane |
| hlc-403 | 10.23.50.43 | Control plane |
| hlc-404 | 10.23.50.44 | Control plane |

**Workers (RPi5s):**
| Hostname | IP | Storage |
|----------|-----|---------|
| hlc-501 | 10.23.50.51 | 1TB NVMe |
| hlc-502 | 10.23.50.52 | 1TB NVMe |
| hlc-503 | 10.23.50.53 | 1TB NVMe |
| hlc-504 | 10.23.50.54 | 1TB NVMe |
| hlc-505 | 10.23.50.55 | 1TB NVMe |
| hlc-506 | 10.23.50.56 | 1TB NVMe |
| hlc-507 | 10.23.50.57 | 1TB NVMe |
| hlc-508 | 10.23.50.58 | 1TB NVMe |

### Storage Architecture

**Per-Node Layout:**
- `/boot`: MicroSD (Class 10 A1) - firmware, kernel, initramfs
- `/` (root): 2x 32GB USB 3.2 in mdadm RAID1 mirror
- Longhorn (Pi5 only): 1TB NVMe (Corsair MP600 Micro)

**Total Cluster Storage:**
- 8TB raw NVMe for Longhorn
- ~4TB usable with 2 replicas (default)

### Storage Classes (Longhorn)
| Class | Replicas | Use Case |
|-------|----------|----------|
| longhorn-critical | 3 | Nextcloud, secrets, databases |
| longhorn-default | 2 | Webservers, persistent apps |
| longhorn-ephemeral | 1 | Game worlds, caches, temp |

### Throughput Limits (Pi5 bottlenecks)
- USB 3.0: ~400 MB/s (caps USB drives)
- PCIe 2.0 x1: ~500 MB/s (caps NVMe)
- MicroSD: ~100 MB/s

## Key Decisions Made

1. **Control plane**: RPi4s (no persistent storage needed)
2. **Workers**: RPi5s with NVMe for Longhorn
3. **Boot strategy**: MicroSD for /boot (no EEPROM changes)
4. **Root filesystem**: mdadm RAID1 on USB pair
5. **Distributed storage**: Longhorn (simple, k3s-native)
6. **Secrets management**: sops-nix with age encryption

## Important Files

- `PREP.md` - Hardware preparation guide
- `~/.claude/plans/effervescent-gathering-wozniak.md` - Full deployment plan
- `modules/cluster/` - Cluster NixOS modules (to be created)
- `hosts/hlc-*/` - Per-node configurations (to be created)

## NixOS Flake Inputs Needed

```nix
nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
sops-nix.url = "github:Mic92/sops-nix";
```

## Commands Reference

```bash
# Laptop shortcuts
nr    # nixos-rebuild switch
ndr   # nixos-rebuild dry-run
gpnr  # git pull && nr

# Build cluster images
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi5

# Remote deploy
nixos-rebuild switch --flake .#hlc-401 --target-host eaglerock@10.23.50.41 --build-host localhost
```

## Related Repos

- `~/git/nix-config` - NixOS configurations (this repo)
- `~/git/happy-little-cloud` - Kubernetes manifests, Helm charts, ArgoCD
