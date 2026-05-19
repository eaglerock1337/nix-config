# Plan: Happy Little Cloud — 12-Node RPi NixOS Cluster

## Context

Expanding the nix-config repo from a single laptop (silicon) to a 12-node Raspberry Pi k3s cluster:

- **4x RPi 4** (hlc-401 to hlc-404): k3s server role — HA embedded etcd, ingress, general workloads
- **8x RPi 5** (hlc-501 to hlc-508): k3s agent role — workloads, Longhorn storage via NVMe

Storage intent: SD card = /boot + fallback live OS. Two 64GB USB3 drives = mdadm RAID 1 main OS
disk. RPi 5s also have 1TB NVMe for Longhorn PV storage.

Deployment: nixos-anywhere (boots from SD, installs to USB RAID over SSH). Secrets: sops-nix
with age keys. App management: ArgoCD app-of-apps with Helm. TLS: cert-manager on marks.dev.

Future cluster ecto-1 (Ryzen 9, x86_64, 4 nodes, all etcd, NVMe root + HDD bulk) shares the
k8s module layer but has its own cluster module directory.

---

## New Flake Inputs

Add to `flake.nix` inputs:

```nix
disko.url = "github:nix-community/disko";
disko.inputs.nixpkgs.follows = "nixpkgs";
sops-nix.url = "github:Mic92/sops-nix";
sops-nix.inputs.nixpkgs.follows = "nixpkgs";
```

Add `nixConfig` block to flake root for nix-community binary cache (avoids compiling RPi kernel):

```nix
nixConfig = {
  extra-substituters = [ "https://nix-community.cachix.org" ];
  extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Cs=" ];
};
```

Add all 12 hosts to `nixosConfigurations`, each with system `aarch64-linux` and modules:
`raspberry-pi-nix.nixosModules.{raspberry-pi,sd-image}`, `disko.nixosModules.disko`,
`sops-nix.nixosModules.sops`, `home-manager.nixosModules.home-manager`,
appropriate `nixos-hardware` module, host config.

- RPi 4 → `nixos-hardware.nixosModules.raspberry-pi-4`
- RPi 5 → `nixos-hardware.nixosModules.raspberry-pi-5`

---

## Module Structure

```text
modules/
├── hosts/                        (unchanged — silicon only)
│   ├── common.nix
│   ├── grub.nix
│   ├── desktop-ui.nix
│   └── gaming.nix
├── home/                         (existing + new cluster user)
│   ├── base.nix, ui.nix, ...     (existing, silicon only)
│   └── cluster.nix               (NEW: bob user shell environment)
├── k8s/                          (NEW: generalized k8s config, cluster-agnostic)
│   ├── k3s/
│   │   ├── server.nix            # role=server, token, firewall ports
│   │   └── agent.nix             # role=agent, token, firewall ports
│   └── longhorn.nix              # kernel mods + open-iscsi (any cluster)
├── hlc/                          (NEW: Happy Little Cloud cluster specifics)
│   ├── base.nix                  # shared node config (packages, SSH, user, sops, motd)
│   ├── rpi4.nix                  # RPi 4: board bcm2711, cgroup params, stateVersion
│   ├── rpi5.nix                  # RPi 5: board bcm2712, NVMe, cgroup params, stateVersion
│   └── disko/
│       ├── usb-raid.nix          # mdadm RAID 1 on sda+sdb → /
│       └── sd-boot.nix           # SD card mmcblk0 → /boot (FAT32)
└── ecto1/                        (STUB: future Ryzen 9 cluster)
    ├── base.nix                  # shared node config for ecto-1
    └── disko/
        ├── nvme-root.nix         # NVMe → / (stub)
        └── hdd-bulk.nix          # HDD bulk storage (stub)
```

---

## Module Contents

### `modules/hlc/base.nix`

- Nix experimental features, GC settings, auto-optimise
- nix-community substituter + trusted key
- Timezone, locale
- `services.openssh` with `PasswordAuthentication = false`
- User `bob`: `isNormalUser`, `wheel`, SSH key (eaglerock's key from gibson)
- `security.sudo.wheelNeedsPassword = false`
- CLI package set (same as common.nix minus GUI: ripgrep, eza, bat, fd, htop, btop, tmux,
  kubectl, k9s, helm, git, curl, wget, age, jq, etc.)
- Bash functions `nr`/`ndr` for local rebuilds
- sops: `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`
- MOTD: placeholder systemd motd unit pointing to `/etc/motd-template` — design TBD
- home-manager wired up for bob: `home-manager.users.bob = import ../../home/bob.nix`

### `home/bob.nix` + `modules/home/cluster.nix`

Bob's home-manager config (cluster-appropriate, no GUI):

- Imports `modules/home/cluster.nix`
- `home.username = "bob"`, `home.homeDirectory = "/home/bob"`, `stateVersion = "25.11"`

`modules/home/cluster.nix` provides:

- Neovim with gruvbox (without GUI plugins)
- Bash aliases: `ll`, `la`, `k` (kubectl), `kns`, `kctx`, `h` (helm)
- tmux config with Gruvbox theme
- `programs.direnv.enable = true`
- `home.sessionVariables`: EDITOR, KUBECONFIG
- Same Gruvbox bash prompt as silicon (SSH-aware coloring already built in)

### `modules/hlc/rpi4.nix`

- `raspberry-pi-nix.board = "bcm2711"`
- `networking.useDHCP = true`
- `system.stateVersion = "25.11"`
- Required cgroup kernel params for k3s on RPi (without these, k3s fails to start):

```nix
boot.kernelParams = [ "cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory" ];
```

### `modules/hlc/rpi5.nix`

- `raspberry-pi-nix.board = "bcm2712"`
- `networking.useDHCP = true`
- `system.stateVersion = "25.11"`
- `boot.initrd.availableKernelModules = [ "nvme" "nvme_core" ]`
- Same cgroup kernel params as rpi4.nix

### `modules/hlc/disko/sd-boot.nix`

SD card (`/dev/mmcblk0`):

- 512MB FAT32 `/boot` partition
- Remaining space: ext4, unmounted (fallback live OS left intact)

### `modules/hlc/disko/usb-raid.nix`

Two USB drives (`/dev/sda` + `/dev/sdb`):

- mdadm RAID 1 → `md/root`
- GPT partition on each → RAID member
- RAID ext4 → mounted at `/`
- `boot.swraid.enable = true`
- Note: USB device paths may need per-node by-id overrides in host config after first boot

### `modules/k8s/k3s/server.nix`

Implements HA embedded etcd across all Pi 4 server nodes. With `clusterInit = true` on hlc-401
and `serverAddr` pointing to hlc-401 on the remaining three, k3s automatically forms a 4-node
embedded etcd cluster — no separate etcd deployment needed.

```nix
services.k3s = {
  enable = true;
  role = "server";
  tokenFile = config.sops.secrets.k3s-token.path;
  # clusterInit = true on hlc-401 only
  # serverAddr = "https://hlc-401:6443" on hlc-402/403/404
};
sops.secrets.k3s-token = {};
networking.firewall.allowedTCPPorts = [ 6443 2379 2380 ];
networking.firewall.allowedUDPPorts = [ 8472 51820 ];
```

### `modules/k8s/k3s/agent.nix`

```nix
services.k3s = {
  enable = true;
  role = "agent";
  tokenFile = config.sops.secrets.k3s-token.path;
  # serverAddr set per-host
};
sops.secrets.k3s-token = {};
networking.firewall.allowedUDPPorts = [ 8472 51820 ];
```

### `modules/k8s/longhorn.nix`

- `boot.kernelModules = [ "iscsi_tcp" "dm_crypt" "nfs" ]`
- `services.openiscsi.enable = true`
- `services.openiscsi.name = "iqn.2024-01.dev.marks:${config.networking.hostName}"`
- `environment.systemPackages = with pkgs; [ nfs-utils cryptsetup ]`
- Note: Longhorn requires NixOS-compatible container images. Override via ArgoCD Helm values
  using `ghcr.io/duckfullstop/nixos-longhorn-manager`.

---

## Host Configs (thin wrappers)

### `hosts/hlc-401/configuration.nix` (bootstrap server)

```nix
imports = [
  ../../modules/hlc/base.nix
  ../../modules/hlc/rpi4.nix
  ../../modules/hlc/disko/sd-boot.nix
  ../../modules/hlc/disko/usb-raid.nix
  ../../modules/k8s/k3s/server.nix
];
networking.hostName = "hlc-401";
services.k3s.clusterInit = true;
sops.defaultSopsFile = ../../secrets/hlc.yaml;
```

### `hosts/hlc-402` / `hlc-403` / `hlc-404`

Same as hlc-401 minus `clusterInit`, plus:

```nix
services.k3s.serverAddr = "https://hlc-401:6443";
```

### `hosts/hlc-501` through `hlc-508` (worker agents)

```nix
imports = [
  ../../modules/hlc/base.nix
  ../../modules/hlc/rpi5.nix
  ../../modules/hlc/disko/sd-boot.nix
  ../../modules/hlc/disko/usb-raid.nix
  ../../modules/k8s/k3s/agent.nix
  ../../modules/k8s/longhorn.nix
];
networking.hostName = "hlc-5XX";
services.k3s.serverAddr = "https://hlc-401:6443";
sops.defaultSopsFile = ../../secrets/hlc.yaml;
```

Refactor existing `hosts/hlc-501/configuration.nix` to match.

---

## Secrets Setup (sops-nix)

One file per cluster — the k3s token is the same across all nodes:

- `secrets/hlc.yaml` — single encrypted file for all HLC nodes, contains `k3s-token`
- Recipients: admin age key + all 12 node host ed25519 keys
- If role-specific secrets emerge later, split into `secrets/hlc-servers.yaml` / `secrets/hlc-agents.yaml`

Each host config points to the same file:

```nix
sops.defaultSopsFile = ../../secrets/hlc.yaml;
```

`.sops.yaml` at repo root declares recipients:

```yaml
creation_rules:
  - path_regex: secrets/hlc\.yaml
    key_groups:
      - age:
        - <admin-age-pubkey>
        - <hlc-401-host-pubkey>   # added after first SD boot
        - <hlc-402-host-pubkey>
        # ... all 12 nodes
```

User setup steps (one-time):

1. `age-keygen -o ~/.config/sops/age/keys.txt`
2. Add pubkey to `.sops.yaml` admin recipients
3. `sops secrets/hlc.yaml` — add k3s-token
4. After provisioning each node: get host ed25519 pubkey, add to `.sops.yaml`, re-run `sops updatekeys secrets/hlc.yaml`

---

## Deployment Flow

### Per-node provisioning

1. `make build-image HOST=hlc-401` — build SD image
2. `make flash-image HOST=hlc-401 DEV=/dev/sdX` — flash SD
3. Boot node → DHCP IP, SSH open as bob
4. `make provision HOST=hlc-401 IP=<dhcp-ip>` → nixos-anywhere installs to USB RAID, reboots
5. Add host age key to `.sops.yaml`, re-encrypt secrets, `make update-node HOST=hlc-401`

### Cluster bring-up order

1. hlc-401 (`clusterInit = true`, bootstraps embedded etcd)
2. hlc-402, 403, 404 (join etcd cluster via `serverAddr`)
3. hlc-501 through hlc-508 (join as agents)
4. ArgoCD bootstrap via `kubectl apply`
5. ArgoCD deploys Longhorn, cert-manager, ingress, application Helm charts

---

## Cluster Upkeep

### NixOS updates

k3s version is pinned to the nixpkgs revision in `flake.lock`. To update both NixOS and k3s:

```bash
make update          # nix flake update — bumps all inputs including nixpkgs
make update-cluster  # nixos-rebuild switch on all 12 nodes sequentially
```

Update servers before agents. The `update-cluster-pi4` target runs first, then `update-cluster-pi5`.
k3s has a one-version skew tolerance between server and agent, so brief mixed-version state during
rolling updates is safe.

### k3s token

**The k3s token cannot be changed after cluster creation without a full reset.** Choose it carefully
before provisioning the first node. See cluster reset procedure below if needed.

### Stopping k3s cleanly

`systemctl stop k3s` alone does not stop containerd or CNI networking. Use the provided script:

```bash
sudo k3s-killall.sh   # available at /run/current-system/sw/bin/k3s-killall.sh
```

Or simply reboot the node.

### Cluster reset (full wipe)

Use this when changing the token or recovering from a broken state. Run on **all nodes**:

1. Set `services.k3s.enable = false` in config, `make update-cluster`
2. Dismount kubelet and delete k3s data:

```bash
KUBELET_PATH=$(mount | grep kubelet | cut -d' ' -f3)
${KUBELET_PATH:+umount $KUBELET_PATH}
rm -rf /etc/rancher/{k3s,node}
rm -rf /var/lib/{rancher/k3s,kubelet,longhorn,etcd,cni}
```

3. Set `services.etcd.enable = false`, rebuild, then delete etcd files:

```bash
rm -rf /var/lib/etcd/
```

4. Reboot all nodes.
5. Re-enable etcd, rebuild, verify `systemctl status etcd`.
6. Re-enable k3s, rebuild, verify `systemctl status k3s`.

### FailedKillPod network error

If you see `failed to get network "cbr0" cached result`, see:
[k3s issue #6185](https://github.com/k3s-io/k3s/issues/6185#issuecomment-1581245331)

---

## Makefile Additions

```makefile
provision HOST IP:        nixos-anywhere --flake .#$(HOST) bob@$(IP)
update-node HOST:         nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(HOST)
update-cluster-pi4:       update hlc-401 through hlc-404 sequentially
update-cluster-pi5:       update hlc-501 through hlc-508 sequentially
update-cluster:           update-cluster-pi4 then update-cluster-pi5
encrypt-secret FILE:      sops encrypt $(FILE)
```

---

## Critical Files

| Action | File |
|--------|------|
| Modify | `flake.nix` |
| Create | `modules/hlc/base.nix` |
| Create | `modules/hlc/rpi4.nix` |
| Create | `modules/hlc/rpi5.nix` |
| Create | `modules/hlc/disko/sd-boot.nix` |
| Create | `modules/hlc/disko/usb-raid.nix` |
| Create | `modules/k8s/k3s/server.nix` |
| Create | `modules/k8s/k3s/agent.nix` |
| Create | `modules/k8s/longhorn.nix` |
| Create | `modules/ecto1/base.nix` (stub) |
| Create | `modules/ecto1/disko/nvme-root.nix` (stub) |
| Create | `modules/ecto1/disko/hdd-bulk.nix` (stub) |
| Create | `modules/home/cluster.nix` |
| Create | `home/bob.nix` |
| Create | `hosts/hlc-401/` through `hlc-404/` |
| Create | `hosts/hlc-502/` through `hlc-508/` |
| Modify | `hosts/hlc-501/configuration.nix` |
| Create | `.sops.yaml` |
| Create | `secrets/hlc.yaml` (one encrypted file for whole cluster) |
| Modify | `Makefile` |

---

## Phasing

- **Phase 1**: Module structure + flake with all 12 hosts + disko configs → images build, nixos-anywhere provisions
- **Phase 2**: sops-nix + k3s modules → cluster forms
- **Phase 3**: Longhorn prerequisites → ArgoCD deploys Longhorn with NixOS-compatible images
- **Phase 4**: cert-manager, ArgoCD app-of-apps, application workloads
- **Future**: ecto-1 cluster using shared `modules/k8s/` layer
