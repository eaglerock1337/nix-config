# Workarounds Ledger

Per current constitution § Pragmatic Phasing (Principle V). Each entry is
append-only; mark `Resolved` in-place when removed. Reviewed at every
phase-exit gate and every `/speckit-plan` cycle.

---

## W-001: Inline minimal host configs (defers Principle III)

- **Site(s)**: After Phase 0 baseline reset, only `hosts/hlc-501/configuration.nix` and `hosts/silicon/*` exist (matching `main`). As Phase 3 re-adds the work-set hosts (`hlc-401`, `hlc-502..508`) and the decom-set host configs (`hlc-402..404`, dry-run-only per Constitution §"Cluster Topology"), each new `hosts/hlc-NNN/configuration.nix` is brought up as a thin per-host file plus inline minimal config until Phase 5 reintroduces the shared modules.
- **Deviates from**: Constitution Principle III (Modular Design)
- **Reason**: The previous attempt to land shared modules + 12 hosts in one push produced a non-recoverable bricked node (hlc-508) and an interactive-ssh hang that did not reproduce in dry-run. Inlining a minimal canonical config per host gives zero blast radius per host and lets us isolate any future module regression to the exact module being reintroduced.
- **Exit condition**: The operator-UX modules (`modules/shell/utilities.nix` toolbox, `modules/shell/common.nix` bash baseline, `modules/shell/prompt.nix` PS1, `modules/motd/default.nix`, `modules/cluster/hlc/motd-banner.nix`, `modules/users/operator.nix`, home-manager modular split, SSH hardening) are reintroduced as a **phase-bundle** per [plan.md → Phase 6](./001-nixos-rpi-cluster/plan.md) and Constitution v1.3.3 §IV "Canary scope". `/speckit-implement` runs all module-creation tasks for the phase, then a single canary on `hlc-501` via `make update-node` + `make smoke-test`. On smoke-test fail: `/speckit-debug` skill drives rollback + incremental reintroduction (comment-out / git-revert new modules one at a time, redeploy, smoke-test) to bisect the breaking module. On smoke-test green: serial fleet roll across `hlc-502..508` then `hlc-401`, smoke-test after each.
- **Target phase / feature**: This spec's Phase 6 (Operator UX). The bundle's single canary closes the inline-host approach across all six modules at once; W-001 is fully Resolved when Phase 6 exits with all 9 work-set nodes on the bundled modular configuration. The post-mortem lesson (regression isolation) is preserved by the bisect-on-fail flow rather than by per-module cadence.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-002: Passwordless `wheel` sudo (`security.sudo.wheelNeedsPassword = false`)

- **Site(s)**: Current sites: `modules/sd/bootstrap.nix` (bootstrap image; permanent for that module, mirrors W-004 disposition) and `modules/cluster/common.nix` (provisioned hosts; added 2026-05-05 so `bob` can satisfy `--use-remote-sudo` on provisioned nodes before secrets management lands). As Phase 6 introduces `modules/users/operator.nix`, the setting moves from the inline `modules/cluster/common.nix` entry into that module; the inline entry in `modules/cluster/common.nix` is removed in T063.
- **Deviates from**: Eventual passwordless-via-key+sops hardened state
- **Reason**: `nixos-rebuild switch --target-host bob@<ip> --use-remote-sudo` (the canary remote-update path) requires `sudo -n true` to succeed without an interactive password prompt. Sops-managed credentials are not yet provisioned. Passwordless wheel on a key-only-ssh node is the standard NixOS bring-up posture; closes when secrets management lands.
- **Exit condition**: sops-nix integration deployed; bob's sudo authorization driven by an age-decrypted credential or an alternate hardened mechanism.
- **Target phase / feature**: Future feature spec — secrets-management spec (`/speckit-specify` not yet run). Out of scope for the current /speckit-plan cycle.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-003: Default `PasswordAuthentication = true` (NixOS 25.11 sshd default)

- **Site(s)**: After Phase 0, no per-host SSH hardening exists; `services.openssh.settings.PasswordAuthentication` retains its NixOS default. Reintroduced explicitly in Phase 5 SSH-hardening sub-step on all 9 work-set hosts (decom-set hosts not flashed; not in scope).
- **Deviates from**: Spec FR-020 (`password authentication MUST be off post-provisioning`)
- **Reason**: Operator explicitly opted to keep password auth enabled as a short-term fallback during initial bring-up. Rationale: a misconfigured `authorized_keys` block (typo, key file path bug, encoding error) on a headless rack node would otherwise brick the node at first boot. Until at least one node has been validated end-to-end with key-only login, password auth provides recovery. Risk accepted on the basis that `bob` has no password set (NixOS defaults disable password login when no password hash exists), so the remaining attack surface is keyboard-interactive auth attempts which an attacker on the management subnet could attempt — explicit known risk.
- **Exit condition**: SSH hardening sub-step in Phase 6 deploys `services.openssh.settings.PasswordAuthentication = false` and `KbdInteractiveAuthentication = false` to all 9 work-set nodes via canary, smoke-test green.
- **Target phase / feature**: Phase 6 (Operator UX) — SSH hardening is the last sub-step of that phase and closes both this entry and W-001.
- **Opened**: 2026-04-26
- **Resolved**: (open)

---

## W-004: `pam_systemd` disabled for sshd in bootstrap image

- **Site(s)**: `modules/sd/bootstrap.nix` — `security.pam.services.sshd.startSession = lib.mkForce false`
- **Deviates from**: NixOS default sshd PAM config (which sets `startSession = true`)
- **Reason**: `pam_systemd` creates and tears down a D-Bus user session on every SSH connection. During teardown of non-PTY command sessions (`ssh host cmd`), D-Bus session cleanup blocks sshd from accepting new connections for several minutes. Observed symptom: smoke-test passes but interactive SSH immediately after is unreachable until sshd self-recovers. Bootstrap image has no need for systemd session tracking, XDG_RUNTIME_DIR, or D-Bus user session activation.
- **Exit condition**: This module is bootstrap-only (`modules/sd/bootstrap.nix`). Full per-host configs do not import it and retain `startSession = true`. No removal needed — workaround scope is intentionally limited to the SD bootstrap environment and does not apply to provisioned nodes.
- **Target phase / feature**: N/A — bootstrap-scoped and permanent for this module.
- **Opened**: 2026-05-02
- **Resolved**: 2026-05-01 (no-op resolution: fix is permanent and intentional; `modules/sd/bootstrap.nix` retains `startSession = lib.mkForce false` indefinitely; provisioned nodes are unaffected)

---

## W-005: `fileSystems."/"` stub commented out in rpi4/rpi5 hardware modules

- **Site(s)**: `modules/hardware/rpi5.nix`, `modules/hardware/rpi4.nix`
- **Deviates from**: Phase 5 design intent (disko provides real layout at provisioning time)
- **Reason**: The `/dev/md0` stub caused SD-boot initramfs to panic on every node because the mdadm RAID array doesn't exist until `nixos-anywhere` runs. On Pi 5, PCIe ethernet is not initialized before the panic, so the switch saw all nodes as "unplugged". Stub was present to let `make dry-run` evaluate before disko is wired; removing it still allows dry-run to pass (NixOS evaluates without a root FS defined).
- **Exit condition**: Resolved via architecture change: `sd-image` module removed from hardware modules entirely. SD bootstrap images built via `mkHlcBootstrap` in `flake.nix` (separate derivation from provisioned `nixosConfigurations`). Hardware modules are now provisioned-config-only; `fileSystems."/"` will be provided by `disko/rpi{4,5}.nix` in Phase 5 (T028/T029) with no conflict.
- **Target phase / feature**: Architecture change (2026-05-02); disko fileSystems wired in Phase 5 (T028/T029).
- **Opened**: 2026-05-02
- **Resolved**: 2026-05-02 (architecture change — sd-image removed from hardware modules; bootstrap images separated into flake.nix packages block)

---

## W-007: `PerSourcePenalties` disabled on SD bootstrap image

- **Site(s)**: `modules/sd/bootstrap.nix` — `services.openssh.settings.PerSourcePenalties = "no"`
- **Deviates from**: OpenSSH 10.2+ default (`PerSourcePenalties yes` — `crash:90 authfail:5 noauth:1 grace-exceeded:10 refuseconnection:10 max:600 min:15`)
- **Reason**: `nixos-anywhere` provisioning opens many short-lived SSH connections from gibson in rapid succession (ssh-copy-id key install, fact-gathering, kexec staging). Default penalty policy interprets the burst as abuse — `noauth:1` per non-authenticating close, stacked ≥ `min:15` — and starts dropping new SYNs from the gibson source IP for 15–600s while RSTing in-flight connections. Symptoms: `make provision` hangs at `### Gathering machine facts ###` or fails at `ssh-copy-id` with `Connection timed out`; `nc -z <node> 22` from gibson times out while ICMP succeeds and `bob` can still log in from a different source IP. The hang-watcher localhost probes generate noise but trip a separate per-source bucket (127.0.0.1) and do not affect the gibson penalty count. Confirmed via `sshd -T | grep persource` showing the OpenSSH 10.2p1 defaults active in the bootstrap image.
- **Exit condition**: Provisioned-host configs (post-`nixos-anywhere`) keep the OpenSSH default (`PerSourcePenalties yes`) — they are not subject to provision-burst traffic. SD bootstrap image is throwaway and on the trusted `10.23.50.0/24` management LAN with key-only auth; PerSourcePenalties contributes no defensive value in that scope.
- **Target phase / feature**: N/A — bootstrap-scoped and permanent for this module (mirrors W-004 / W-006 disposition).
- **Opened**: 2026-05-04
- **Resolved**: (open — bootstrap-scoped permanent)

---

## W-008: TCP timestamps disabled on SD bootstrap image

- **Site(s)**: `modules/sd/bootstrap.nix` — `boot.kernel.sysctl."net.ipv4.tcp_timestamps" = 0`
- **Deviates from**: NixOS / kernel default (`net.ipv4.tcp_timestamps = 1`, RFC 1323 PAWS enabled)
- **Reason**: 2026-05-05 testing confirmed the SSH-hang root cause is **not** conntrack as W-006 originally hypothesised: `nf_conntrack`, `nf_conntrack_ipv{4,6}`, and `nf_nat` are blacklisted via `boot.blacklistedKernelModules`; `lsmod` empty; `nft list ruleset` empty; W-007 `PerSourcePenalties=no` confirmed live in `sshd -T`. Yet a single non-PTY `ssh bob@hlc-501 '<cmd>'` invocation reliably wedges outbound TCP for ~265s while ICMP continues to work — three samples (264s, 273s, 265s) cluster tightly, indicating a kernel-deterministic timeout (matches `tcp_retries2=15` exhaustion path). Wedge is in the kernel TCP stack itself, not netfilter. `tcp_timestamps=0` is a known mitigation for several Pi vendor kernel TCP regressions; the bootstrap LAN is trusted v4-only and has no PAWS dependency, so cost is nil.
- **Exit condition**: Either (a) Pi5 vendor kernel regression fixed upstream in nvmd nixos-raspberrypi and bootstrap image picks up a kernel where the wedge no longer reproduces with `tcp_timestamps=1`, or (b) full root-cause identified and a more targeted fix applied. If (a) succeeds, this entry resolves and W-006 should be re-evaluated for similar removal.
- **Target phase / feature**: Kernel regression follow-up alongside W-006; doc sweep at Phase 8 T097/T098. If still unresolved at spec close-out, open follow-on issue tracking nvmd kernel updates.
- **Opened**: 2026-05-05
- **Resolved**: (open)

---

## W-009: TCP retransmit cap reduced (`tcp_retries2 = 5`)

- **Site(s)**: `modules/cluster/hlc/vendor-kernel-tcp.nix` — `boot.kernel.sysctl."net.ipv4.tcp_retries2" = 5`. Module is staged but **not yet imported anywhere** as of opening; wire-up will land alongside the workable-state declaration.
- **Deviates from**: Kernel default `tcp_retries2 = 15` (RFC 1122 §4.2.3.5 R2 ≥ 100s).
- **Reason**: The W-008 wedge has a recovery floor at `tcp_retries2` exhaustion. Three observed samples (264s, 273s, 265s) match the default-15 backoff schedule. Cutting to 5 collapses the recovery floor to ~25–30s, making the wedge invisible to operator workflow even when the underlying root cause is still present. Trade-off: established TCP sessions will give up faster on transient packet loss; HLC is LAN-only, low-loss, so the trade-off is favourable. Operator workflow also benefits from `make smoke-test` retries succeeding within seconds rather than minutes.
- **Exit condition**: Removed once the underlying TCP wedge is root-caused and fixed (W-006 / W-008 path) or once the vendor kernel ships with the regression patched. Until then this is a workflow-friendliness band-aid, not a correctness fix.
- **Target phase / feature**: Vendor-kernel mitigations follow-up alongside W-006 / W-008. Doc sweep at Phase 8 T097/T098.
- **Opened**: 2026-05-05
- **Resolved**: (open)

---

## W-010: Root SSH key in bootstrap image + `--phases disko,install,reboot` in `make provision`

- **Site(s)**: `modules/sd/bootstrap.nix` — `users.users.root.openssh.authorizedKeys.keys = [ operatorPubkey ]`; `Makefile` — `provision` target uses `--phases disko` then `--phases install,reboot` (split by W-011 firmware mount step); root SSH required for both the W-011 intermediate mount and the install phase.
- **Deviates from**: nixos-anywhere default kexec-based provisioning flow; principle of minimal root exposure.
- **Reason**: Two related issues. (1) Pi4/Pi5 vendor kernel 6.12.47 kexec fails unconditionally with `Can't kexec: CPUs are stuck in the kernel` — `vc4`, `brcmfmac`, and other Pi hardware drivers do not implement kexec quiesce callbacks; `kexec_file_load` returns `EBUSY`. `--phases disko,install,reboot` skips kexec entirely. (2) The nixos-anywhere install phase (copying Nix store closure + running nixos-install) requires root SSH access on the target; `bob` with passwordless sudo is insufficient for this phase. Confirmed 2026-05-05: disko phase works as `bob`, install phase requires `root@`. Bootstrap image is throwaway; management LAN is trusted (10.23.50.0/24); key-only auth.
- **Exit condition**: Either (a) nvmd vendor kernel gains kexec support (restores default nixos-anywhere flow, removes both deviations), or (b) nixos-anywhere adds a non-root path for the no-kexec install phase (removes root key entry, keeps `--phases`). Remove when kexec provision works end-to-end on Pi.
- **Target phase / feature**: Vendor-kernel follow-up alongside W-006/W-008/W-009. Doc sweep at Phase 8 T097/T098.
- **Opened**: 2026-05-05
- **Resolved**: (open)

---

## W-011: Explicit `/boot/firmware` mount between disko and install phases in `make provision`

- **Site(s)**: `Makefile` — `provision` target; `ssh root@$(HOST).$(HLC_DOMAIN) "mkdir -p /mnt/boot/firmware && mount /dev/mmcblk0p1 /mnt/boot/firmware"` between the disko and install phases.
- **Deviates from**: Single-invocation `nixos-anywhere` provisioning flow.
- **Reason**: nixos-anywhere does not mount pre-existing filesystems absent from the disko schema before running the nixos-install bootloader phase. The Pi firmware bootloader installer (`nixos-generations-builder.sh`) is called during the install phase and requires `/boot/firmware` to be mounted to copy firmware files. `mmcblk0p1` (the SD card vfat firmware partition) is not managed by disko — it is a pre-existing partition from the bootstrap image — so disko does not mount it. Result: the bootloader cp fails with `No such file or directory` for `/boot/firmware`. Confirmed on hlc-502 (2026-05-05): `/mnt/boot` absent from the freshly-installed ext4 root after the disko phase; mmcblk0p1 unmounted. Fix: split provision into `--phases disko` then explicit mount then `--phases install,reboot`.
- **Exit condition**: nixos-anywhere gains support for mounting pre-existing filesystems (not managed by disko) before the bootloader phase, OR the Pi firmware bootloader installer is changed to mount its own target partition. Until then this intermediate mount step is required for any Pi host provisioned via nixos-anywhere.
- **Target phase / feature**: nixos-anywhere upstream behavior. Doc sweep at Phase 8 T097/T098. If still unresolved at spec close-out, open a follow-on issue tracking nixos-anywhere updates.
- **Opened**: 2026-05-05
- **Resolved**: (open)

---

## W-006: NixOS firewall disabled on SD bootstrap image

- **Site(s)**: `modules/sd/bootstrap.nix` — `networking.firewall.enable = false`
- **Deviates from**: NixOS default (`networking.firewall.enable = true`)
- **Reason**: nf_conntrack TCP state machine is corrupted by SSH session teardown in the Pi5 vendor kernel 6.12.47. Symptom: after any SSH session closes, TCP fails in both directions (outbound SYN-ACK never matched by conntrack INPUT chain; inbound TCP SYNs also dropped) while ICMP continues to work. Hang lasts ~10 minutes until stale SYN_SENT conntrack entries time out. Bootstrap image is on a trusted private management LAN (10.23.50.0/24); the only inbound service is sshd on port 22 with key-only auth. Firewall provides no meaningful security benefit in this context.
- **Exit condition**: Kernel bug fixed upstream in nvmd fork / Pi5 vendor kernel, or bootstrap image moves to a kernel version where this is not present. If the provisioned (non-bootstrap) host configs also hit this issue, a targeted nftables workaround (accept-all from management subnet, bypass conntrack) should be applied there instead of disabling the firewall globally.
- **Target phase / feature**: Kernel regression fix in nvmd nixos-raspberrypi upstream. Tracked via Phase 8 T097/T098 doc sweep — if still unresolved at spec close-out, open a follow-on issue to monitor nvmd kernel updates and remove the flag once confirmed fixed.
- **Opened**: 2026-05-02
- **Resolved**: (open)

