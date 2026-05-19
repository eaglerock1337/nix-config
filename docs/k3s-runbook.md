# k3s Cluster Operations Runbook

> **Cluster**: Happy Little Cloud (HLC) — `hlc-NNN.marks.dev`
> **Operator user**: `bob`
> **k3s datastore**: embedded etcd (no external etcd)
> **Scope**: Cluster lifecycle — setup, operations, upgrades, teardown.
> Bootstrap provisioning (NixOS, disko, RAID) is in the cluster-bootstrap spec.

---

## Cluster Topology

| Hosts | Hardware | k3s Role | Workload Pool | Storage |
|-------|----------|----------|---------------|---------|
| `hlc-401..403` | Pi 4 (bcm2711) | server (etcd + control-plane) | `rpi4` — light/stateless | RAID1 USB root only |
| `hlc-404` | Pi 4 (bcm2711) | server (control-plane, no etcd) | `rpi4` — light/stateless | RAID1 USB root only |
| `hlc-501..508` | Pi 5 (bcm2712) | agent (worker) | `rpi5` — standard/stateful | RAID1 USB root + NVMe `/srv` |

**Design**: 3 Pi 4s run etcd for odd-count quorum (tolerate 1 failure).
hlc-404 runs as a k3s server with `--disable-etcd` — it participates in the
control-plane (API server, scheduler, controller-manager) and accepts rpi4-pool
workloads, but stays out of etcd elections. It serves as a warm standby that
can be promoted to an etcd member if one of the other three goes down.
Pi 5s are pure workers with NVMe-backed Longhorn storage for stateful workloads.

**Network**: 10.23.50.0/24 — IPs derived from hostname (hlc-501 → 10.23.50.51).

**Storage layout**:

- `/` — ext4 on mdadm RAID1 (two USB drives), all nodes
- `/srv` — xfs on NVMe (Pi 5 workers only), designated for Longhorn
- `/boot/firmware` — vfat on SD card (firmware + bootloader)

**Decommissioned**: hlc-503 (defective USB controller), hlc-507 (hardware issue)

---

## 1. Fresh Cluster Setup

### Prerequisites

All nodes must already be NixOS-provisioned with k3s prereqs (Phase 7):

```bash
# Verify on each node
ssh bob@hlc-501.marks.dev k8s-health-check
```

The health check validates: k3s binary present, kernel modules loaded
(`br_netfilter`, `overlay`, `ip_tables`), sysctls set, cgroups v2 active,
and k3s service enabled-but-stopped (no cluster state yet).

### Step 1: Initialize the first server node

The init node **must** use `--cluster-init` to start embedded etcd. Without
this flag, k3s defaults to SQLite and you cannot add servers later without
reprovisioning.

```yaml
# /etc/rancher/k3s/config.yaml on hlc-401
cluster-init: true
tls-san:
  - hlc-401.marks.dev
  - 10.23.50.41
  # add VIP here if using kube-vip / load balancer later
node-label:
  - "hlc.marks.dev/pool=rpi4"
  - "hlc.marks.dev/hardware=pi4"
```

No `NoSchedule` taint — Pi 4 server nodes accept light workloads.

```bash
sudo systemctl start k3s
```

Verify etcd mode (not SQLite):

```bash
# etcd process should be running
ps aux | grep etcd

# This file should NOT exist — its presence means SQLite mode
ls /var/lib/rancher/k3s/server/db/state.db
```

### Step 2: Retrieve and store the cluster token

```bash
sudo cat /var/lib/rancher/k3s/server/token
```

Store this in sops-nix or your secrets manager. Every joining node needs it.

### Step 3: Join etcd server nodes (one at a time)

hlc-402 and hlc-403 join as full etcd members, giving you a 3-member quorum.

```yaml
# /etc/rancher/k3s/config.yaml on hlc-402, hlc-403
server: https://hlc-401.marks.dev:6443
token: <token from init node>
tls-san:
  - hlc-402.marks.dev   # this node's own SAN
  - 10.23.50.42
node-label:
  - "hlc.marks.dev/pool=rpi4"
  - "hlc.marks.dev/hardware=pi4"
```

```bash
sudo systemctl start k3s
```

**Wait for each member to show `started` before adding the next**:

```bash
# On hlc-401 — watch member count grow: 1 → 2 → 3
etcdctl member list
```

Adding nodes simultaneously risks election instability. Sequential is safer.

### Step 4: Join the non-voting server (hlc-404)

hlc-404 runs as a k3s server but with etcd disabled. It participates in
the control-plane and accepts rpi4-pool workloads, but doesn't affect
etcd quorum. It can be promoted to an etcd member during DR (see Section 5).

```yaml
# /etc/rancher/k3s/config.yaml on hlc-404
server: https://hlc-401.marks.dev:6443
token: <token from init node>
disable-etcd: true
tls-san:
  - hlc-404.marks.dev
  - 10.23.50.44
node-label:
  - "hlc.marks.dev/pool=rpi4"
  - "hlc.marks.dev/hardware=pi4"
  - "hlc.marks.dev/etcd-standby=true"
```

```bash
sudo systemctl start k3s
```

Verify hlc-404 is a server but NOT in etcd:

```bash
kubectl get nodes   # hlc-404 shows as control-plane
etcdctl member list # only 3 members (401, 402, 403)
```

### Step 5: Join agent (worker) nodes

```yaml
# /etc/rancher/k3s/config.yaml on hlc-501..508
server: https://hlc-401.marks.dev:6443
token: <cluster token>
node-label:
  - "hlc.marks.dev/pool=rpi5"
  - "hlc.marks.dev/hardware=pi5"
  - "hlc.marks.dev/storage=nvme"
```

```bash
sudo systemctl start k3s-agent
```

Agents can join in parallel — they don't participate in etcd elections.

### Step 6: Apply node labels and roles

Labels set via `node-label` in config.yaml persist across restarts. These
additional labels are applied one-time via kubectl:

```bash
# Control-plane role label (k3s sets this automatically on servers,
# but explicit labeling is clearer for selectors)
for n in hlc-401 hlc-402 hlc-403 hlc-404; do
  kubectl label node $n node-role.kubernetes.io/control-plane=true
done

# Worker role label
for n in hlc-501 hlc-502 hlc-504 hlc-505 hlc-506 hlc-508; do
  kubectl label node $n node-role.kubernetes.io/worker=true
done

# Longhorn storage eligibility (Pi 5 only — they have /srv NVMe)
for n in hlc-501 hlc-502 hlc-504 hlc-505 hlc-506 hlc-508; do
  kubectl label node $n storage.hlc/longhorn=true
done
```

### Step 7: Verify cluster health

```bash
kubectl get nodes -o wide --show-labels
# All nodes Ready, correct pool labels

etcdctl endpoint status --write-out=table
# 3 etcd members (401, 402, 403), one leader

kubectl get pods -n kube-system
# CoreDNS, flannel, metrics-server, etc. all Running
```

---

## 2. Workload Pools and Node Roles

### Two-pool model

The cluster has two workload pools, targeted via `nodeSelector` or
`nodeAffinity` on the `hlc.marks.dev/pool` label:

| Pool | Label | Nodes | Use for | Avoid |
|------|-------|-------|---------|-------|
| `rpi4` | `hlc.marks.dev/pool=rpi4` | hlc-401..404 | Stateless services, cron jobs, lightweight controllers, monitoring agents | Anything needing persistent volumes or heavy I/O |
| `rpi5` | `hlc.marks.dev/pool=rpi5` | hlc-501..508 | Standard workloads, stateful apps, anything needing Longhorn PVs | Nothing excluded — this is the primary pool |

### Targeting workloads to a pool

**Simple nodeSelector** (most deployments):

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      nodeSelector:
        hlc.marks.dev/pool: rpi5    # or rpi4 for light workloads
```

**nodeAffinity** (prefer a pool but allow fallback):

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 80
              preference:
                matchExpressions:
                  - key: hlc.marks.dev/pool
                    operator: In
                    values: ["rpi5"]
```

**Anti-affinity for stateful workloads** (keep off Pi 4s entirely):

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: hlc.marks.dev/storage
                    operator: In
                    values: ["nvme"]
```

### Control-plane nodes (hlc-401..404)

All four Pi 4s run k3s server and accept rpi4-pool workloads (no `NoSchedule`
taint). The difference is etcd participation:

| Node | etcd | Control-plane | Workloads | Notes |
|------|------|---------------|-----------|-------|
| hlc-401 | voting member | yes | rpi4 pool | init node (`--cluster-init`) |
| hlc-402 | voting member | yes | rpi4 pool | |
| hlc-403 | voting member | yes | rpi4 pool | |
| hlc-404 | **disabled** | yes | rpi4 pool | warm standby (`--disable-etcd`) |

**etcd quorum**: 3 voting members, quorum = 2, tolerates 1 failure. hlc-404
can be promoted to replace a failed member (see Section 5: DR Promotion).

**Resource constraints**: Pi 4s have ~4 GB RAM and modest CPU. Keep workloads
light: stateless services, CronJobs, monitoring exporters, cluster utilities.
etcd + API server already consume a portion of available resources on the
three voting members; hlc-404 has slightly more headroom since it skips etcd.

**No NVMe, no Longhorn**: Pi 4 nodes have no `/srv`. Never label them
`storage.hlc/longhorn=true` or schedule PVC-backed workloads here.

### Worker nodes (hlc-501..508)

**Purpose**: Primary workload pool. No etcd participation.

**Longhorn storage on `/srv`**: The xfs NVMe mount at `/srv` is pre-configured
for Longhorn persistent volumes. When setting up Longhorn:

```yaml
# Longhorn settings (helm values or CR)
defaultSettings:
  defaultDataPath: /srv/longhorn
  storageMinimalAvailablePercentage: 15

# Only schedule replicas on NVMe-backed nodes
nodeSelector:
  storage.hlc/longhorn: "true"
```

Create the data directory on each worker before enabling Longhorn:

```bash
for n in hlc-501 hlc-502 hlc-504 hlc-505 hlc-506 hlc-508; do
  ssh bob@${n}.marks.dev sudo mkdir -p /srv/longhorn
done
```

**NVMe health**: Monitor wear periodically:

```bash
ssh bob@hlc-501.marks.dev sudo smartctl -a /dev/nvme0n1
```

### Role summary

```text
hlc-401  server  │ init node, etcd voter, control-plane, pool=rpi4
hlc-402  server  │ etcd voter, control-plane, pool=rpi4
hlc-403  server  │ etcd voter, control-plane, pool=rpi4
hlc-404  server  │ etcd STANDBY (--disable-etcd), control-plane, pool=rpi4
hlc-501  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
hlc-502  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
hlc-504  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
hlc-505  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
hlc-506  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
hlc-508  agent   │ worker, pool=rpi5, Longhorn (/srv NVMe)
```

---

## 3. Upgrading the Cluster

### k3s version upgrades

k3s upgrades are binary replacements. The NixOS module pins the version via
nixpkgs — bump the flake input, rebuild, deploy.

**Order matters**: upgrade server nodes first, then agents.

#### Rolling upgrade procedure

```bash
# 1. Update flake inputs on workstation
nix flake update

# 2. Dry-run on one server node
make dry-run HOST=hlc-401

# 3. Upgrade server nodes one at a time
#    Wait for each to rejoin and show Ready before proceeding
for n in hlc-401 hlc-402 hlc-403 hlc-404; do
  make update-node HOST=$n
  sleep 30
  kubectl get nodes
  etcdctl endpoint health
done

# 4. Upgrade agent nodes (can be more aggressive, 2-3 at a time)
for n in hlc-501 hlc-502 hlc-504 hlc-505 hlc-506 hlc-508; do
  kubectl drain $n --ignore-daemonsets --delete-emptydir-data
  make update-node HOST=$n
  kubectl uncordon $n
done
```

#### Server node upgrade considerations

Since Pi 4 server nodes run workloads, drain rpi4-pool pods before upgrading:

```bash
# Drain light workloads off the server before upgrade
kubectl drain hlc-401 --ignore-daemonsets --delete-emptydir-data
make update-node HOST=hlc-401
# Wait for etcd to rejoin
etcdctl endpoint health
kubectl uncordon hlc-401
```

#### Rollback

```bash
# If a node is broken after upgrade
make rollback HOST=hlc-501

# k3s also supports generation-based rollback via NixOS
# The last 5 boot generations are kept on the firmware partition
```

### NixOS configuration changes (non-k3s)

Same `make update-node` workflow. For changes that affect k3s behavior
(kernel modules, sysctls, firewall rules), drain the node first:

```bash
kubectl drain hlc-501 --ignore-daemonsets --delete-emptydir-data
make update-node HOST=hlc-501
kubectl uncordon hlc-501
```

### etcd version

etcd is embedded in the k3s binary — it upgrades with k3s. No separate
etcd upgrade path.

---

## 4. Node Management

### Adding a server node (etcd voter)

```bash
# 1. Provision the node with NixOS (make provision HOST=hlc-403)
# 2. Configure /etc/rancher/k3s/config.yaml (see Section 1 Step 3)
#    Do NOT set disable-etcd
# 3. Start k3s
sudo systemctl start k3s

# 4. Verify etcd membership from an existing server
etcdctl member list

# 5. Apply labels
kubectl label node hlc-403 node-role.kubernetes.io/control-plane=true
```

### Adding a server node (non-voting standby)

```bash
# 1. Provision the node with NixOS (make provision HOST=hlc-404)
# 2. Configure /etc/rancher/k3s/config.yaml (see Section 1 Step 4)
#    Set disable-etcd: true
# 3. Start k3s
sudo systemctl start k3s

# 4. Verify it's NOT in etcd
etcdctl member list   # should not include hlc-404
kubectl get nodes     # hlc-404 should show as control-plane

# 5. Apply labels
kubectl label node hlc-404 node-role.kubernetes.io/control-plane=true
```

No taint needed on either type — server nodes accept rpi4-pool workloads.

### Adding an agent node

```bash
# 1. Provision the node
# 2. Configure /etc/rancher/k3s/config.yaml (see Section 1 Step 4)
# 3. Start k3s-agent
sudo systemctl start k3s-agent

# 4. Apply labels
kubectl label node hlc-506 node-role.kubernetes.io/worker=true
kubectl label node hlc-506 storage.hlc/longhorn=true
```

### Removing a worker node (graceful)

```bash
# 1. Drain (evicts pods, respects PDBs)
kubectl drain hlc-506 --ignore-daemonsets --delete-emptydir-data

# 2. Stop k3s on the node
ssh bob@hlc-506.marks.dev sudo systemctl stop k3s-agent

# 3. Delete the node object
kubectl delete node hlc-506
```

### Removing a server node

**More involved** — etcd membership must be cleaned up, and any rpi4-pool
workloads will reschedule to remaining servers.

```bash
# 1. Drain (moves both control-plane components and rpi4-pool workloads)
kubectl drain hlc-404 --ignore-daemonsets --delete-emptydir-data

# 2. Stop k3s on the node
ssh bob@hlc-404.marks.dev sudo systemctl stop k3s

# 3. Remove etcd member (from a remaining server)
etcdctl member list
# Find the member ID for hlc-404
etcdctl member remove <MEMBER_ID>

# 4. Delete the k8s node object
kubectl delete node hlc-404
```

**Never remove a server if it would break quorum** (e.g., going from 2 to 1).

### Cordon / Uncordon

```bash
# Block scheduling without evicting existing pods
kubectl cordon hlc-501

# Re-enable scheduling
kubectl uncordon hlc-501
```

### Taints and labels

```bash
# If you ever need to temporarily block workloads on a server node
# (e.g., during maintenance that doesn't warrant a full drain):
kubectl taint node hlc-401 maintenance=true:NoSchedule
kubectl taint node hlc-401 maintenance=true:NoSchedule-

# Add/remove labels
kubectl label node hlc-501 storage.hlc/longhorn=true
kubectl label node hlc-501 storage.hlc/longhorn-
```

### Token management

```bash
# Token location on server nodes
sudo cat /var/lib/rancher/k3s/server/token

# Rotate the cluster token (k3s v1.28+, rolling restart required)
# See: https://docs.k3s.io/cli/token
```

---

## 5. etcd Operations

k3s uses embedded etcd. Data dir: `/var/lib/rancher/k3s/server/db/etcd/`.

### Shell alias

The TLS flags are tedious. Add this on server nodes:

```bash
alias etcdctl='ETCDCTL_API=3 etcdctl \
  --endpoints https://127.0.0.1:2379 \
  --cacert /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert   /var/lib/rancher/k3s/server/tls/etcd/client.crt \
  --key    /var/lib/rancher/k3s/server/tls/etcd/client.key'
```

> **Note**: `etcdctl` is not always bundled with k3s. If absent, add
> `pkgs.etcd` to the cluster common module.

### Health and status

```bash
# Member list
etcdctl member list

# Endpoint health (all members)
etcdctl endpoint health

# Endpoint status (leader, DB size, raft index)
etcdctl endpoint status --write-out=table

# etcd DB size (watch for growth)
etcdctl endpoint status --write-out=table | grep -E 'ENDPOINT|DB SIZE'
```

### Snapshots

```bash
# Manual snapshot
k3s etcd-snapshot save --name manual-$(date +%Y%m%d-%H%M%S)

# List snapshots
k3s etcd-snapshot ls

# Default location
ls /var/lib/rancher/k3s/server/db/snapshots/
```

k3s auto-snapshots every 12h (5 retained). Override in config:

```yaml
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 10
```

### Restore

**Stop k3s on ALL server nodes before restoring.**

```bash
# Stop all servers
for n in hlc-401 hlc-402 hlc-403 hlc-404; do
  ssh bob@${n}.marks.dev sudo systemctl stop k3s
done

# Restore on the init node
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot>

# The above exits after resetting. Restart:
sudo systemctl start k3s

# Then restart remaining servers (they re-join from restored state)
for n in hlc-402 hlc-403 hlc-404; do
  ssh bob@${n}.marks.dev sudo systemctl start k3s
done

# Wait for all nodes Ready before restarting agents
kubectl get nodes
```

### Compaction and defrag

k3s does not auto-compact etcd. On a home lab this is mostly benign,
but run quarterly or if DB size grows noticeably.

```bash
# Current revision
etcdctl endpoint status --write-out=json | jq '.[0].Status.header.revision'

# Compact (drops history before REV)
etcdctl compact <REV>

# Defrag (frees disk, takes member offline briefly — one at a time)
etcdctl defrag
```

### DR: Promoting the standby to etcd voter

If an etcd member (hlc-401, 402, or 403) goes down and cannot be recovered
quickly, promote hlc-404 to restore the 3-member quorum.

**Prerequisite**: The cluster still has quorum (2 of 3 etcd members alive).
If quorum is already lost (2+ members down), skip to etcd Restore instead.

#### Promote hlc-404

```bash
# 1. Verify current etcd state — should show 2 healthy, 1 failed
etcdctl endpoint health
etcdctl member list

# 2. Stop k3s on hlc-404
ssh bob@hlc-404.marks.dev sudo systemctl stop k3s

# 3. Edit config: remove disable-etcd (or set to false)
#    /etc/rancher/k3s/config.yaml on hlc-404:
#      disable-etcd: false   (or remove the line entirely)

# 4. Restart k3s — it joins etcd as a new voting member
ssh bob@hlc-404.marks.dev sudo systemctl start k3s

# 5. Verify 3 etcd members again
etcdctl member list
etcdctl endpoint health
```

The cluster now has 3 etcd voters (e.g., 401, 403, 404) and tolerates 1
failure again.

#### When the failed node recovers

You have two options: bring it back as an etcd voter (going to 4 members
temporarily) or make it the new standby.

**Option A: Make the recovered node the new standby** (recommended)

```bash
# 1. Remove the failed node's stale etcd member entry
etcdctl member list
etcdctl member remove <STALE_MEMBER_ID>

# 2. On the recovered node, clear old etcd state
ssh bob@hlc-402.marks.dev sudo rm -rf /var/lib/rancher/k3s/server/db/etcd/

# 3. Set disable-etcd: true in its config.yaml
#    It becomes the new standby, swapping roles with hlc-404

# 4. Start k3s
ssh bob@hlc-402.marks.dev sudo systemctl start k3s

# 5. Verify: 3 etcd members (401, 403, 404), recovered node is server-only
etcdctl member list
kubectl get nodes
```

**Option B: Restore the original topology**

```bash
# 1. Remove stale etcd entry for the failed node
etcdctl member remove <STALE_MEMBER_ID>

# 2. Clear old etcd state on the recovered node
ssh bob@hlc-402.marks.dev sudo rm -rf /var/lib/rancher/k3s/server/db/etcd/

# 3. Ensure disable-etcd is NOT set in the recovered node's config
# 4. Start k3s on the recovered node — it rejoins as an etcd voter
ssh bob@hlc-402.marks.dev sudo systemctl start k3s

# 5. Verify 4 etcd members temporarily
etcdctl member list

# 6. Demote hlc-404 back to standby
ssh bob@hlc-404.marks.dev sudo systemctl stop k3s
# Set disable-etcd: true in hlc-404's config
ssh bob@hlc-404.marks.dev sudo systemctl start k3s

# 7. Remove hlc-404's etcd member entry (it left on restart)
#    k3s should handle this automatically, but verify:
etcdctl member list   # should show 3 members (401, 402, 403)
```

#### Rules of thumb

- **Always maintain exactly 3 etcd voters** in steady state. Never sit at 2
  or 4 long-term.
- **Promote before removing** — don't remove the failed member from etcd
  until the standby is promoted and healthy. Removing first drops you to 2
  members where both must be up (worse than 3 with 1 down).
- **Clear etcd state on recovered nodes** — stale etcd data causes peer cert
  mismatches and join failures. Always `rm -rf` the etcd dir before rejoining.
- The standby role is just a config flag — any Pi 4 server can be voter or
  standby. Swap roles as needed.

### Transitioning single-node to distributed etcd

If you started with one server (`--cluster-init`) and want to add HA:

1. The init node is already in etcd cluster mode — no changes needed on it
2. Add server nodes one at a time per Section 1 Step 3
3. Verify member list grows after each join
4. Test quorum by stopping one server and confirming `kubectl` still works

**If the init node was started WITHOUT `--cluster-init`**: k3s is in SQLite
mode. You must either reprovision or do a painful state migration. Avoid this
by always using `--cluster-init` on the first server, even for a single-node
cluster.

---

## 6. Health Checks and Debugging

### Quick cluster check

```bash
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get componentstatuses              # deprecated but functional
```

### Pool-specific checks

```bash
# Which nodes are in each pool?
kubectl get nodes -L hlc.marks.dev/pool

# Pods running on rpi4 pool (control-plane nodes)
for n in hlc-401 hlc-402 hlc-403 hlc-404; do
  echo "--- $n ---"
  kubectl get pods -A --field-selector spec.nodeName=$n
done

# Pods running on rpi5 pool
for n in hlc-501 hlc-502 hlc-504 hlc-505 hlc-506 hlc-508; do
  echo "--- $n ---"
  kubectl get pods -A --field-selector spec.nodeName=$n
done
```

### Service status

```bash
systemctl status k3s                       # server nodes
systemctl status k3s-agent                 # agent nodes
```

### Logs

```bash
journalctl -u k3s -f                       # server log (follow)
journalctl -u k3s-agent -f                 # agent log
journalctl -u k3s -n 100 --no-pager        # last 100 lines
# Debug mode: add `debug: true` to config.yaml
```

### Kubeconfig

```bash
# Default (root-only)
/etc/rancher/k3s/k3s.yaml

# Copy for bob
sudo install -m 600 -o bob /etc/rancher/k3s/k3s.yaml /home/bob/.kube/config

# Or just export
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### Useful one-liners

```bash
# Events sorted by time
kubectl get events -A --sort-by='.lastTimestamp'

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A

# All images running in the cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.nodeName}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}'

# Find pods on a specific node
kubectl get pods -A --field-selector spec.nodeName=hlc-501

# Check resource pressure on rpi4 pool (limited RAM)
kubectl top nodes -l hlc.marks.dev/pool=rpi4
```

### Common failure modes

| Symptom | Likely cause | Where to look |
|---------|-------------|---------------|
| `kubectl` hangs or refuses connection | k3s not running or kubeconfig wrong | `systemctl status k3s`; check `/etc/rancher/k3s/k3s.yaml` |
| Node shows `NotReady` | CNI (flannel) not initialized, kubelet issue | `kubectl describe node <node>`; `journalctl -u k3s` on that node |
| etcd `no leader` | Quorum lost (need majority of servers up) | Bring at least ⌈n/2⌉+1 server nodes back online |
| etcd `context deadline exceeded` | etcd overloaded or disk I/O bottleneck | `etcdctl endpoint status`; check USB health; defrag if DB large |
| `certificate has expired` | Annual cert rotation missed | `k3s certificate rotate`; restart k3s |
| New node: `token does not match` | Token mismatch | Compare `/var/lib/rancher/k3s/server/token` with joining config |
| Rejoining server after wipe | etcd rejects stale peer certs | Remove old member first: `etcdctl member remove <ID>` |
| Pods stuck `Pending` | No nodes match nodeSelector, or resources exhausted | `kubectl describe pod`; check pool labels and resource requests |
| Pods landing on wrong pool | Missing or wrong `nodeSelector` | Check deployment spec; verify node labels with `kubectl get nodes --show-labels` |
| rpi4 node OOM | Workload too heavy for Pi 4 (4 GB RAM) | `kubectl top nodes`; move workload to rpi5 pool |
| Longhorn volume not attaching | `/srv` not mounted or node not labeled | Verify: `df -h /srv`; `kubectl get node -L storage.hlc/longhorn` |
| Stateful pod scheduled on rpi4 | PVC requires Longhorn, but rpi4 has no storage | Add `nodeSelector: hlc.marks.dev/pool: rpi5` to the workload |

---

## References

- [k3s docs — Embedded etcd HA](https://docs.k3s.io/datastore/ha-embedded)
- [k3s docs — Backup and Restore](https://docs.k3s.io/datastore/backup-restore)
- [k3s docs — Token](https://docs.k3s.io/cli/token)
- [k3s docs — Certificate rotation](https://docs.k3s.io/cli/certificate)
- [k3s docs — Upgrades](https://docs.k3s.io/upgrades)
- [Longhorn docs — Node selector](https://longhorn.io/docs/latest/advanced-resources/deploy/node-selector/)
- [etcd ops guide](https://etcd.io/docs/v3.5/op-guide/)
