# Quickstart: NixOS RPi Cluster Foundation

**Feature**: 001-nixos-rpi-cluster | **Plan reset**: 2026-04-26

> This quickstart matches the **shell-stripped plan** (plan.md, 2026-04-26 round 4).
> Phase A uses default bash prompt + standard tool packages only — no custom PS1,
> no syshelp, no custom bashrc. Styled PS1 and syshelp are reintroduced in Phase C.
> kitty users: connect with `TERM=xterm-256color ssh bob@<host>` or use alacritty.
> Phase C+ usage (sops, disko, k3s, ArgoCD) returns to this doc once those phases are planned.

## Prerequisites

- **Build host**: gibson (Ryzen 9 5950X, NixOS) with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`.
- **Hardware**: 12× Raspberry Pi (4× Pi4, 8× Pi5), 12× MicroSD, headless rack with
  Unifi-managed `10.23.50.0/24` subnet. DHCP reservations for all 12 MACs.
- **Operator SSH key** present in `flake.nix`-derived host configs (hard-coded in
  Phase A; refactored in Phase C).

## Phase A0: Strip to baseline + triage

**Goal**: All host configs stripped to pure NixOS defaults. Canaries for both
Pi4 (hlc-401) and Pi5 (hlc-501) smoke-test clean before rolling to remaining nodes.

### 1. Verify host configs are minimal

Each `hosts/hlc-NNN/configuration.nix` should be ~12 lines with NO imports of
shell, prompt, utilities, MOTD, or operator user modules:

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

```bash
make dry-run-all    # must exit 0 for all 12 hosts
```

### 2. Build canaries

```bash
make build HOST=hlc-401    # full Pi4 toplevel
make build HOST=hlc-501    # full Pi5 toplevel
```

### 3. Flash + boot canaries

```bash
make flash-image HOST=hlc-401 DEV=/dev/sdX
make flash-image HOST=hlc-501 DEV=/dev/sdY
# Insert SDs, power on, wait for DHCP lease.
```

If hlc-401 is unreachable: check DHCP MAC reservation in Unifi, confirm Pi4 image
(bcm2711 board), verify switch port, try a different SD card.

### 4. Smoke-test canaries

```bash
make smoke-test HOST=hlc-401 IP=10.23.50.41
make smoke-test HOST=hlc-501 IP=10.23.50.51
```

Both must pass. If either fails → stop, diagnose before proceeding.

**SSH note**: kitty users connect with `TERM=xterm-256color ssh bob@<host>` or use
alacritty. The default NixOS terminfo database does not include xterm-kitty.

### A0 exit gate

Both canaries green. Interactive SSH shows default bash prompt with no escape code artifacts.

## Phase A1: Add standard tool packages

**Prerequisites**: A0 exit gate passes (all canaries green, default bash prompt confirmed).

**Goal**: All 9 work-set nodes have standard sysadmin tool packages. Default bash prompt
unchanged — no PS1 customization.

### 1. Add tool packages inline to each host config

Add `environment.systemPackages` directly in each `hosts/hlc-NNN/configuration.nix`
(alphabetically sorted):

```nix
environment.systemPackages = with pkgs; [
  git
  htop
  jq
  ripgrep
  tmux
];
```

Keep it lean — add only tools needed for triage. No prompt, no bashrc, no syshelp.

### 2. Canary deploy (hlc-501 first)

```bash
make canary HOST=hlc-501 IP=10.23.50.51
ssh bob@10.23.50.51    # verify tools available: git --version, htop, etc.
```

### 3. Roll to hlc-401, then remaining work-set nodes

```bash
make canary HOST=hlc-401 IP=10.23.50.41
# Then hlc-502 through hlc-508 one at a time:
make canary HOST=hlc-502 IP=10.23.50.52
# ... smoke-test after each
```

### A1 exit gate

All 9 work-set nodes pass smoke-test. `git`, `htop`, `jq`, `ripgrep`, `tmux`
available. Default bash prompt on interactive SSH (no escape code artifacts).

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

**Prerequisites**: B exit gate passes (static IPs, host pubkeys inventoried).

Module reintroduction order — one canary cycle per module, never bundled:

1. `modules/users/operator.nix` — parameterized `bob` user
2. `modules/shell/utilities.nix` — sysadmin packages + `syshelp` (replaces inline systemPackages)
3. `modules/shell/common.nix` — bash history, aliases
4. `modules/shell/prompt.nix` — **styled PS1** (requires `\e` bug fix first — see research.md R-011)
5. `modules/motd/default.nix` + `modules/cluster/hlc/motd.nix` — HLC banner
6. SSH hardening

For each module:

```bash
# 1. Add/fix module file under modules/
# 2. Import in ONE canary host (hlc-501 recommended)
make build HOST=hlc-501
make canary HOST=hlc-501 IP=10.23.50.51

# 3. Manual interactive ssh — must reach prompt within 5s:
ssh bob@10.23.50.51

# 4. If green, roll to remaining work-set nodes; smoke-test all.
# 5. Commit. One module per commit. Never bundle.
```

**prompt.nix** is highest-risk (prior ssh-hang suspected origin). Before deploying:
fix `\033` → `\e` and remove wrapping double-quotes per research.md R-011. Test
interactive PTY ssh explicitly. Use `nixos-rebuild build-vm` if aarch64 VM is feasible.

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
