# Quickstart: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Plan reset**: 2026-04-26

> This quickstart matches the **reset plan** (plan.md, 2026-04-26). The previous
> quickstart described the failed Phase A flow (shared shell/MOTD modules, 12
> hosts in one push). It is replaced by the canary-driven baseline-first flow
> below. Phase C+ usage (sops, disko, k3s, ArgoCD) returns to this doc once
> those phases are planned.

## Prerequisites

- **Build host**: gibson (Ryzen 9 5950X, NixOS) with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`.
- **Hardware**: 12× Raspberry Pi (4× Pi4, 8× Pi5), 12× MicroSD, headless rack with
  Unifi-managed `10.23.50.0/24` subnet. DHCP reservations for all 12 MACs.
- **Operator SSH key** present in `flake.nix`-derived host configs (hard-coded in
  Phase A; refactored in Phase C).

## Phase A0: Triage — recover bricked nodes

If you are reading this for the first time after a known-bad deploy, **start
here**. Do not proceed to A1 until A0 exits clean.

```bash
# Reproduce ssh-hang in a VM (no rack risk):
nixos-rebuild build-vm --flake .#hlc-501
./result/bin/run-*-vm     # then try `ssh bob@<vm-ip>` — should hang same as rack node

# Bisect the modules->hosts diff vs. main:
git diff main..HEAD -- hosts/ modules/
```

Reflash the bricked rack node with the **main-branch minimal config** under its
hostname:

```bash
git checkout main -- hosts/hlc-501/configuration.nix     # template
# Edit copy: rename hostname to hlc-508, change board if Pi4, save under hosts/hlc-508/
make build-image HOST=hlc-508
make flash-image HOST=hlc-508 DEV=/dev/sdX
# Re-rack SD; power-cycle node; confirm:
make smoke-test HOST=hlc-508 IP=10.23.50.58
```

Record the root cause in `research.md` § R-011.

## Phase A1: Baseline — get all 12 nodes online

### 1. Confirm host configs are minimal

Each `hosts/hlc-NNN/configuration.nix` should be ~12 lines:

```nix
{ ... }: {
  raspberry-pi-nix.board = "bcm2711";   # bcm2712 for Pi5 (hlc-501–508)
  networking.hostName = "hlc-NNN";
  networking.useDHCP = true;
  services.openssh.enable = true;
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "<gibson pubkey>" ];
  };
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "25.11";
}
```

No imports. No shared modules. No SSH hardening. No prompt. No MOTD.

### 2. Eval-check all 12 hosts

```bash
make dry-run-all
```

Must exit 0.

### 3. Build canary images

```bash
make build HOST=hlc-401          # full toplevel — catches things dry-run misses
make build HOST=hlc-501
```

### 4. Flash + boot the two canaries

```bash
make flash-image HOST=hlc-401 DEV=/dev/sdX
make flash-image HOST=hlc-501 DEV=/dev/sdY
# Insert SDs, power on Pis, wait for DHCP lease.
```

### 5. Smoke-test the canaries

```bash
make smoke-test HOST=hlc-401 IP=10.23.50.41
make smoke-test HOST=hlc-501 IP=10.23.50.51
```

Smoke-test must pass: ping, non-PTY ssh, PTY ssh-to-prompt within 5s.
If either fails → STOP, return to A0.

### 6. Roll to remaining 10 nodes

One Pi4 + one Pi5 at a time. Smoke-test after each.

### Exit gate

```bash
for h in hlc-40{1..4} hlc-50{1..8}; do
  make smoke-test HOST=$h IP=$(make ip HOST=$h);
done
```

All 12 green.

## Phase A2: Remote-update validation

```bash
# Trivial change — add htop to one host's environment.systemPackages:
$EDITOR hosts/hlc-401/configuration.nix
make canary HOST=hlc-401 IP=10.23.50.41
# canary = build → switch --target-host → smoke-test → auto-rollback on failure

# Verify rollback path:
nixos-rebuild switch --rollback --flake .#hlc-401 --target-host bob@10.23.50.41 --use-remote-sudo
make smoke-test HOST=hlc-401 IP=10.23.50.41
```

Repeat once on a Pi5. Document the loop. Phase A complete.

## Phase B: Static IPs + host-key inventory

After A2 passes. Move from DHCP reservations to declared static IPs in nix
(`networking.interfaces.eth0.ipv4.addresses`). Still no shared modules. One
canary, smoke-test, rollout. After: collect each node's
`/etc/ssh/ssh_host_ed25519_key.pub` and record in `data-model.md` for later
sops-nix age recipients.

## Phase C: Layered module reintroduction (one at a time)

For each of (operator, shell/common, shell/prompt, shell/utilities, motd,
ssh-hardening):

```bash
# 1. Add module file under modules/
# 2. Import in ONE canary host (hlc-404 recommended)
make build HOST=hlc-404
make canary HOST=hlc-404 IP=10.23.50.44

# 3. Manual interactive ssh — must reach prompt within 5s:
ssh bob@10.23.50.44

# 4. If green, roll to remaining 11; smoke-test all.
# 5. Commit. One module per commit. Never bundle.
```

`shell/prompt.nix` is the highest-risk module (suspected ssh-hang origin). Test
interactive PTY shell explicitly before rolling out.

## Phase D / E

Disko/USB-RAID/sops/k3s/ArgoCD. Out of scope for this quickstart until Phase D
is planned.

## Make targets (Phase A1 set)

| Target | Purpose |
|---|---|
| `make dry-run HOST=hlc-NNN` | Eval one host (cheap) |
| `make dry-run-all` | Eval all 12 |
| `make build HOST=hlc-NNN` | Full toplevel build (gates flashing) |
| `make build-image HOST=hlc-NNN` | SD card image |
| `make flash-image HOST=hlc-NNN DEV=/dev/sdX` | Flash SD |
| `make smoke-test HOST=hlc-NNN IP=<ip>` | Reachability + PTY ssh check |
| `make canary HOST=hlc-NNN IP=<ip>` | Build + switch + smoke-test + auto-rollback |
| `make update-node HOST=hlc-NNN IP=<ip>` | Plain switch (use only after canary on other nodes greenlit the change) |
