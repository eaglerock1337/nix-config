# Data Model: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Date**: 2026-04-25

## Entities

### ClusterNode

A physical Raspberry Pi with a declared role in the k3s cluster.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| hostname | string | `hlc-{4,5}XX` pattern, unique | Network hostname and NixOS config name |
| fqdn | string | `<hostname>.marks.dev` | Fully qualified domain name |
| ip | IPv4 | `10.23.50.{41-44,51-58}`, unique | Static DHCP reservation |
| mac | string | discovered at first boot | Ethernet MAC for DHCP reservation |
| piModel | enum | `rpi4` \| `rpi5` | Hardware model, determines board config |
| boardId | string | `bcm2711` (Pi4) \| `bcm2712` (Pi5) | raspberry-pi-nix board identifier |
| role | enum | `server` \| `agent` | k3s cluster role |
| nodeType | string | `control` (Pi4) \| `worker` (Pi5) | Human-readable node classification |
| isInitServer | boolean | `true` only for hlc-401 | Whether this node bootstraps etcd |
| agePublicKey | string | derived from SSH host key | sops-nix decryption recipient |
| stateVersion | string | `"25.11"` | NixOS state version |

**Instances**:

| Hostname | IP | Model | Type | k3s Role | Init |
|----------|-----|-------|------|----------|------|
| hlc-401 | 10.23.50.41 | rpi4 | control | server | yes |
| hlc-402 | 10.23.50.42 | rpi4 | control | server | no |
| hlc-403 | 10.23.50.43 | rpi4 | control | server | no |
| hlc-404 | 10.23.50.44 | rpi4 | control | server | no |
| hlc-501 | 10.23.50.51 | rpi5 | worker | agent | no |
| hlc-502 | 10.23.50.52 | rpi5 | worker | agent | no |
| hlc-503 | 10.23.50.53 | rpi5 | worker | agent | no |
| hlc-504 | 10.23.50.54 | rpi5 | worker | agent | no |
| hlc-505 | 10.23.50.55 | rpi5 | worker | agent | no |
| hlc-506 | 10.23.50.56 | rpi5 | worker | agent | no |
| hlc-507 | 10.23.50.57 | rpi5 | worker | agent | no |
| hlc-508 | 10.23.50.58 | rpi5 | worker | agent | no |

### StorageLayout

Per-node storage tier configuration.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| bootDevice | path | `/dev/mmcblk0` | MicroSD card for /boot (FAT32, 512MB) |
| raidDevices | list[path] | `[/dev/sda, /dev/sdb]` | USB 3.2 drives for RAID1 mirror |
| raidMountpoint | path | `/` | Root filesystem on mdadm RAID1 (ext4) |
| nvmeDevice | path \| null | `/dev/nvme0n1` (workers) \| null (control) | NVMe for Longhorn PV storage |
| nvmeManagedBy | string \| null | `"longhorn"` \| null | NVMe is Longhorn-managed, not partitioned by NixOS |

**Per node type**:
- **Control nodes** (Pi4): SD boot + 2× 64GB USB 3.2 RAID1 root. No NVMe.
- **Workers** (Pi5): SD boot + 2× 64GB USB 3.2 RAID1 root + 1TB NVMe for Longhorn PVs.

### ClusterSecret

Encrypted value stored in the repository, decryptable at runtime.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| name | string | `k3s-token` | sops secret key name |
| encryptedFile | path | `secrets/hlc.yaml` | sops-encrypted YAML file |
| recipients | list[ageKey] | admin key + 12 node host keys | Who can decrypt |
| runtimePath | path | `/run/secrets/k3s-token` | Decrypted path managed by sops-nix |

### SDImage

Bootable NixOS image for initial node provisioning.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| piModel | enum | `rpi4` \| `rpi5` | Target hardware model |
| arch | string | `aarch64-linux` | Target architecture |
| outputPath | path | `result/sd-image/*.img.zst` | Build output (zstd-compressed) |
| contents | list | firmware, kernel, initramfs, base NixOS | What's on the SD card |

Only two images are needed — one per Pi model. All control nodes share the Pi4 image;
all workers share the Pi5 image.

### OperatorUser

Parameterized system user for a given system class.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| username | string | `bob` \| `eaglerock` \| `slimer` | Login name |
| systemClass | string | `hlc` \| `desktop` \| `ecto1` | Which system type |
| sshKeys | list[string] | at least 1 | Authorized SSH public keys |
| groups | list[string] | always includes `wheel` | User groups |
| homeManagerConfig | path | e.g. `home/bob.nix` | Home-manager entry point |

**Per system class**:
- **hlc**: user `bob`, SSH key from gibson, cluster shell env
- **desktop**: user `eaglerock`, full desktop home-manager config
- **ecto1** (stub): user `slimer`, placeholder config

### MOTDConfig

Parameterized message-of-the-day configuration.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| clusterName | string \| null | e.g. `"Happy Little Cloud"` | Display name |
| asciiArt | string \| null | multiline ASCII banner | Cluster-specific art |
| tagline | string \| null | e.g. `"Let's build a happy little cloud."` | Quote or tagline |
| attribution | string \| null | e.g. `"~ Bob Ross"` | Quote attribution |
| showHostname | boolean | default `true` | Whether to display node hostname |

**Per cluster**:
- **hlc**: ASCII "HLC" banner + Bob Ross quote (replicates existing Debian MOTD)
- **ecto1** (stub): Generic hostname-only banner, no theme
- **desktop**: No MOTD (module not imported)

## Relationships

```text
ClusterNode 1──1 StorageLayout       (each node has exactly one storage layout)
ClusterNode *──1 ClusterSecret       (all nodes share the same k3s token)
ClusterNode 1──1 OperatorUser        (each node has one operator user)
ClusterNode 1──1 MOTDConfig          (each node has one MOTD config)
ClusterNode *──1 SDImage             (many nodes share one image per Pi model)
ClusterNode(control, non-init) ──> ClusterNode(hlc-401)  (join etcd via serverAddr)
ClusterNode(worker) ──> ClusterNode(hlc-401)              (join k3s via serverAddr)
```

## State Transitions

### Node Provisioning Lifecycle

```text
        ┌─────────┐
        │  BARE   │  Physical Pi, no OS
        └────┬────┘
             │ flash SD card (make flash-image)
             v
        ┌─────────┐
        │ SD_BOOT │  Boots from MicroSD, DHCP IP, SSH open
        └────┬────┘
             │ nixos-anywhere over SSH (make provision)
             v
     ┌───────────────┐
     │  PROVISIONED  │  NixOS on USB RAID, rebooted to persistent config
     └───────┬───────┘
             │ add age key to .sops.yaml, sops updatekeys, rebuild
             v
     ┌───────────────┐
     │ SECRET_READY  │  Node can decrypt k3s token
     └───────┬───────┘
             │ k3s starts, joins cluster
             v
     ┌───────────────┐
     │ CLUSTER_READY │  Node shows Ready in kubectl get nodes
     └───────────────┘
             │
             │ nixos-rebuild switch (make update-node)
             v
     ┌───────────────┐
     │   UPDATING    │  Rebuild in progress
     └───────┬───────┘
             │ rebuild complete, k3s restarts
             v
     ┌───────────────┐
     │ CLUSTER_READY │  Back to ready state
     └───────────────┘
```

### Cluster Bring-Up Sequence

```text
1. hlc-401 (clusterInit=true)    → etcd leader, k3s API server bootstraps
2. hlc-402, hlc-403, hlc-404     → join etcd via serverAddr=hlc-401:6443
3. hlc-501 through hlc-508       → join as agents via serverAddr=hlc-401:6443
4. ArgoCD bootstrap              → kubectl apply (one-time manual step)
5. ArgoCD syncs app-of-apps      → Longhorn, cert-manager, ingress deploy
```

### Rolling Update Sequence

```text
Control nodes (servers first, init node last for stability):
  for each in [hlc-402, hlc-403, hlc-404, hlc-401]:
    1. make update-node HOST=<hostname>
    2. Verify node Ready + etcd healthy (etcdctl endpoint health)
    3. Proceed to next

Workers (agents, any order):
  for each in [hlc-501 .. hlc-508]:
    1. make update-node HOST=<hostname>
    2. Verify node Ready (kubectl get node <hostname>)
    3. Proceed to next

Invariant: Never fewer than 2 healthy control nodes (etcd quorum = 3 of 4)
```

## Validation Rules

- **Hostname format**: Must match `hlc-[45]\d{2}` pattern
- **IP allocation**: Control nodes in `10.23.50.41-44`, workers in `10.23.50.51-58`
- **RAID pair**: Exactly 2 USB devices per node, both present for RAID1
- **NVMe exclusivity**: Worker NVMe must not be partitioned as root; reserved for Longhorn
- **Secret recipients**: `.sops.yaml` must list admin key + all 12 node keys
- **Control node count**: Exactly 4 for embedded etcd HA (tolerates 1 failure)
- **Init server**: Exactly 1 node with `clusterInit = true` (hlc-401)
- **Token immutability**: k3s token cannot change after cluster creation without full reset
