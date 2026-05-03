# Breakfix: Pi5 Bootstrap SSH Session-Teardown Hang

**Status**: Open / active troubleshooting
**Opened**: 2026-05-02
**Affected hosts**: hlc-501 (confirmed), hlc-503 (confirmed). hlc-505/hlc-506 have a separate SD-card-write failure ruled out of scope here.
**Image**: `modules/sd/bootstrap.nix` — Pi5 vendor kernel 6.12.47 (nvmd nixos-raspberrypi), OpenSSH 10.2p1, NixOS 25.11, sd-image livesd.

This document is a working incident record, not a post-mortem. The intent is
to allow a fresh `/speckit-debug` session (or human) to resume troubleshooting
without re-deriving the failure surface. Mirror conventions from
`post-mortem-26-04-29.md`. Pass this file to `/speckit-analyze` when the
issue closes.

---

## Symptom

After any SSH session to a freshly-flashed Pi5 bootstrap node disconnects,
TCP becomes unreachable in both directions for ~5–10 minutes. ICMP continues
to work the entire window. Behavior:

- First `make smoke-test HOST=hlc-501` after boot: passes.
- Second `make smoke-test` (or any subsequent SSH connection attempt): hangs
  during TCP handshake. Client `ssh -v` stops at `setting O_NONBLOCK` or
  earlier; never receives banner.
- Existing live SSH sessions are unaffected — they continue to function, can
  run commands, observe state.
- `ping` from gibson succeeds throughout the hang window.
- Hang clears spontaneously after ~5–10 minutes; node is then reachable until
  the next session teardown re-triggers it.

Reproducible on multiple hosts (501 and 503 confirmed). Therefore not
SD-card-specific or host-specific corruption — systemic to the bootstrap
image build.

---

## Hypotheses ruled out (with evidence)

Each fix attempted in `modules/sd/bootstrap.nix`, image rebuilt and reflashed,
hang reproduced post-fix. Listed in chronological order.

| # | Fix attempted | Evidence it didn't fix | Status |
|---|---|---|---|
| 1 | `security.pam.services.sshd.startSession = lib.mkForce false` (W-004) — kills `pam_systemd` D-Bus user-session creation/teardown on sshd PAM stack | Hang reproduces; `cat /etc/pam.d/sshd` confirms only `pam_env`/`pam_unix`, no `pam_systemd` | Fix retained (correct, but not root cause) |
| 2 | Makefile smoke-test corrected to non-PTY `ssh ... uname -a` (no `-t`) per Constitution v1.3.3 | Non-PTY SSH also hangs on second invocation | Fix retained (constitution-correct) |
| 3 | `networking.firewall.enable = false` (W-006) — disables nftables service | Hang reproduces | Fix retained, see #4 |
| 4 | `boot.blacklistedKernelModules = [ "nf_conntrack" "nf_conntrack_ipv4" "nf_conntrack_ipv6" "nf_nat" ]` — kernel-level conntrack removal | `ssh bob@hlc-501 'lsmod \| grep -cE "conntrack\|nf_nat"'` returns `0` on running image. Hang still reproduces. **Conclusively rules out nf_conntrack TCP state machine theory.** | Fix retained |
| 5 | `networking.enableIPv6 = false` + sysctl `disable_ipv6 = 1` | Hang reproduces | Fix retained |
| 6 | `services.journald.storage = "volatile"` + tmpfs `/tmp` + tmpfs `/var/tmp` — eliminates SD-card I/O on every sshd auth/session log write | Hang reproduces with `mount` confirming both tmpfs mounts active | Fix retained |
| 7 | `ethtool -K end0 tso off gso off gro off lro off` — disables Pi5 NIC hardware offloads (bcmgenet/MACB driver in vendor kernel) | Hang reproduces with all four offloads confirmed `off` via `ethtool -k` | Not yet baked into nix; manual test only |

Every fix above was applied and the symptom did not change. Each fix is still
correct on its own merits and the bootstrap.nix retains them.

Side note on naming: Pi5 NIC is `end0`, not `eth0`. Multiple `ethtool` test
attempts initially failed with `no device matches name` until corrected.

---

## Current bootstrap.nix state

`modules/sd/bootstrap.nix` (canonical state at time of writing — read the file
for ground truth):

- pam_systemd off in sshd PAM (#1)
- firewall off + conntrack/nf_nat blacklisted (#3, #4)
- IPv6 off (#5)
- journald volatile, tmpfs /tmp + /var/tmp (#6)
- bob: wheel + key-only-ssh + passwordless sudo (W-002 extended for bootstrap)

Open workarounds: W-001 (inline host configs, pre-Phase 6), W-002 (passwordless
wheel, now bootstrap-scoped too), W-003 (PasswordAuthentication default during
bring-up — note bootstrap.nix already sets it to `false`), W-006 (this issue).
Resolved: W-004 (no-op), W-005 (architecture change).

---

## Symptom profile → remaining hypothesis space

The selective failure mode (TCP both directions wedge while ICMP works,
self-recovery ~5–10 min, existing established sessions unaffected) is
consistent with a **socket / listener / TCP-stack state issue**, not a block
I/O hang. Block I/O would freeze whole syscalls indefinitely without timed
recovery.

Two suspects remain:

1. **OpenSSH 10.2p1 `sshd-session` split-binary architecture**. OpenSSH 9.8
   introduced a separation between the listener `sshd` and the per-connection
   `sshd-session` binary. Session-teardown handling is new code and has had
   reported regressions. If `sshd-session` exit handling wedges the listener
   socket, no new connection accepts until the listener clears.

2. **Pi5 vendor kernel 6.12.47 TCP stack or NIC driver**. Even with hardware
   offloads disabled (#7), kernel-side socket cleanup or TX/RX path under the
   driver could be wedged. Vendor kernel from nvmd's nixos-raspberrypi fork
   is a unique factor versus mainline.

These can be bisected by swapping the SSH server while holding the kernel
fixed, or swapping the kernel while holding sshd fixed.

---

## Decided next action: dropbear bisect

Replace OpenSSH with dropbear in `modules/sd/bootstrap.nix`. Bootstrap-only
change, fully reversible, no impact on provisioned-host config.

Why dropbear:
- Single binary, single process per connection. No listener/session split.
- No PAM, no D-Bus, no systemd-logind handoff.
- Reads `~/.ssh/authorized_keys` directly.
- Compatible with `make smoke-test` and `nixos-rebuild --target-host
  --use-remote-sudo` (server side is interchangeable from a plain SSH client).

Outcome interpretation:
- **Hang gone with dropbear** → OpenSSH 10.x sshd-session split is the bug.
  Solution: pin OpenSSH older, or report upstream and hold dropbear in
  bootstrap until fixed.
- **Hang persists with dropbear** → bug lives in kernel TCP stack or `end0`
  driver. Move to kernel swap.

Backup plan (kernel swap): `nvmd/nixos-raspberrypi` flake (rev
`533931954e43aeb09dfc604bdc062412b1487b69`) does not expose discrete named
kernel packages. Kernel selection happens by overlay inclusion. Relevant
attributes from `nix flake show`:

- `overlays.vendor-kernel` — Pi vendor kernel (currently the suspect, 6.12.47)
- `overlays.vendor-firmware` — vendor firmware blobs (needed for boot)
- `overlays.bootloader` — vendor bootloader (needed for boot)
- `overlays.kernel-and-firmware` — combined vendor kernel+firmware bundle
- `nixosModules.raspberry-pi-5` — composite module that wires the above
- `nixosModules.sd-image` — sd-image generator (already used by `mkHlcBootstrap`
  in this repo's `flake.nix`)

Swap strategy if dropbear bisect points to kernel:

1. Edit `flake.nix` (or wherever nvmd overlays are composed) to drop
   `vendor-kernel` / `kernel-and-firmware` from the bootstrap derivation
   while retaining `bootloader` + `vendor-firmware` (the latter two are still
   required for Pi5 boot).
2. Result: mainline nixpkgs aarch64 kernel (likely linuxPackages 6.12+ LTS
   from nixpkgs-25.11). Pi5 has had upstream support since kernel ~6.6, so
   ethernet + USB + SD should work on mainline. PCIe/HAT+/NVMe/video may
   regress, but bootstrap doesn't need them.
3. Build, flash, test hang reproducer. If hang gone → vendor-kernel-specific
   bug; report to nvmd upstream and either pin mainline in bootstrap or wait
   for fix.

This is a structurally larger change than dropbear and takes more rebuild
time. Pursue only after dropbear bisect proves kernel is the suspect.

USB rootfs (operator suggestion) deferred. Symptom profile (TCP-only, ICMP
fine, timed recovery) does not match block I/O. USB rootfs is Phase 5 work
regardless and will be pursued separately.

---

## Pre-flight diagnostics not yet captured

If the dropbear bisect is inconclusive or further triage is needed, the
following data has not been captured during a hang window and would be
high-value:

- `ss -tan` from a still-live SSH session showing TCP socket states during
  hang (look for half-open SYN_RECV / TIME_WAIT pile-up).
- `journalctl -u sshd -n 50 --no-pager` from inside the hang window — does
  sshd log accept attempts, or is it silent?
- `ps -eo pid,ppid,stat,comm | grep -E "sshd"` — D-state (uninterruptible)
  processes? Zombie sshd-session children?
- `dmesg -T | tail -100` for kernel-side complaints.
- tcpdump capture from gibson during the hang to confirm whether SYN is
  reaching 501 and whether 501 is responding.

These were proposed but not run before the operator chose the dropbear path.
A fresh debug session may want this data first.

---

## How to resume (handoff checklist)

1. Read `modules/sd/bootstrap.nix` — confirm current state matches table above.
2. Read `specs/WORKAROUNDS.md` — confirm W-001 through W-006 ledger.
3. Confirm operator is back on the bootstrap workflow (`make build-image`,
   `make smoke-test`, etc.).
4. Implement dropbear swap in `modules/sd/bootstrap.nix`:
   - `services.openssh.enable = false;`
   - `services.dropbear.enable = true;`
   - Verify `users.users.bob.openssh.authorizedKeys.keys` is honored by
     dropbear (it reads `~/.ssh/authorized_keys` directly — should work).
   - Decide whether to retain a code comment referencing this breakfix doc.
5. `make build-image HOST=hlc-501 REBUILD=1`. Flash to a known-bad reproducer
   (501 or 503). Run multiple `make smoke-test` cycles plus interactive ssh
   teardown. Record outcome.
6. If hang gone: design path forward (dropbear permanent in bootstrap, or
   pin older OpenSSH). Update this doc with conclusion + close.
7. If hang persists: ask operator for `nix flake show
   github:nvmd/nixos-raspberrypi` kernel-attribute output. Plan kernel swap.
8. Pass this file to `/speckit-analyze` when the issue closes for spec
   consistency check.

---

## Files in scope

- `modules/sd/bootstrap.nix` — primary edit surface
- `specs/WORKAROUNDS.md` — workaround ledger (W-002 extended, W-006 open)
- `Makefile` — smoke-test target (already corrected to non-PTY)
- `specs/001-nixos-rpi-cluster/breakfix-26-05-02-pi5-ssh-hang.md` — this doc

## Constraint reminders (operator-facing)

- Network-only diagnosis. No HDMI / serial / keyboard suggestions.
- Constitution v1.3.3 §VIII: operator observations are authoritative input;
  conflicts raised as questions, never silent reframings.
- Bootstrap image is throwaway — bias toward decisive bisecting changes
  rather than incremental tuning.
