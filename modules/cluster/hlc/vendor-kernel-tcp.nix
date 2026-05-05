{ lib, pkgs, ... }:

# Pi5 / Pi4 vendor-kernel TCP-wedge mitigations bundle.
#
# Background: nvmd nixos-raspberrypi vendor kernel 6.12.47 wedges outbound TCP
# for ~265s after non-PTY ssh teardown while ICMP continues to work. Three
# samples (264s, 273s, 265s) clustered tightly indicate a kernel-deterministic
# timeout (matches tcp_retries2=15 exhaustion). W-006 originally blamed
# nf_conntrack; 2026-05-05 testing disproved that — modules blacklisted,
# lsmod empty, wedge persists. Bug is in the kernel TCP socket layer or
# bcm2712 NIC TX path. We are stuck on the vendor kernel because mainline
# Pi5 ethernet support is incomplete (DT bindings landing piecemeal in
# 6.13/6.14).
#
# This module is the kitchen-sink mitigation set — every plausible knob
# turned to a safer value. Once we reach a workable state we iterate to
# back off fixes that turn out to be redundant. Until then, ship them all.
#
# Scope: import from BOTH bootstrap image and provisioned hosts so the
# entire HLC fleet has the same mitigation surface.
#
# Workarounds covered:
#   W-004 — pam_systemd startSession off (D-Bus user session teardown blocks sshd)
#   W-006 — conntrack module load blocked + firewall off (originally suspected;
#           kept because removing them did not regress and disproving them
#           required the harder evidence below)
#   W-007 — sshd PerSourcePenalties off (provision burst trips OpenSSH 10.2 default)
#   W-008 — net.ipv4.tcp_timestamps off (PAWS path suspected in TCP wedge)
#   W-009 — net.ipv4.tcp_retries2 = 5 (band-aid: cuts wedge recovery from
#           ~265s to ~30s so workflow tolerates residual hangs)
#
# Additional hardening below is exploratory — no W-NNN until proven needed
# or proven redundant.
#
# This module is NOT imported by default. Wire from
#   modules/cluster/hlc/default.nix (provisioned hosts) and/or
#   modules/sd/bootstrap.nix (SD bootstrap image)
# once smoke-tested on a single canary node.

{
  # --- Kernel TCP-stack mitigations -------------------------------------------

  boot.kernel.sysctl = {
    # W-008 — PAWS off; bootstrap LAN is trusted, no PAWS dependency.
    "net.ipv4.tcp_timestamps" = 0;

    # W-009 — cut retransmit cap so a wedged socket cleans up in ~30s instead
    # of ~265s. Default 15 ≈ 13–30min for established conn, 924s for
    # established-with-data. 5 ≈ 25s. Trades resilience on lossy WAN for
    # responsiveness on trusted LAN; HLC is LAN-only.
    "net.ipv4.tcp_retries2" = 5;

    # Faster orphaned-conn cleanup. Default 8 ≈ 1.6–7min.
    "net.ipv4.tcp_orphan_retries" = 3;

    # FIN_WAIT_2 timeout. Default 60s. Trim to free sockets faster on heavy
    # provision bursts.
    "net.ipv4.tcp_fin_timeout" = 15;

    # SYN/SYN-ACK retry caps — fail fast on a wedged peer instead of long
    # exponential backoff. Default 5/5.
    "net.ipv4.tcp_syn_retries" = 3;
    "net.ipv4.tcp_synack_retries" = 3;

    # SACK off — Pi vendor kernels have repeatedly shipped SACK regressions.
    # On LAN with low loss the gain from SACK is negligible.
    "net.ipv4.tcp_sack" = 0;
    "net.ipv4.tcp_dsack" = 0;
    "net.ipv4.tcp_fack" = 0;

    # TIME_WAIT recycling for outgoing connections (safe; replaces the
    # removed tcp_tw_recycle which was unsafe).
    "net.ipv4.tcp_tw_reuse" = 1;

    # SYN backlog headroom for provision-burst spikes.
    "net.ipv4.tcp_max_syn_backlog" = 4096;
    "net.core.somaxconn" = 4096;
    "net.core.netdev_max_backlog" = 5000;

    # Keepalive faster — detect a wedged peer in ~3min instead of ~2hr
    # default. Helps masters from gibson notice a dead Pi.
    "net.ipv4.tcp_keepalive_time" = 120;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_keepalive_probes" = 3;

    # IPv6 stays off (also set in bootstrap.nix; harmless duplicate).
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  # --- W-006: conntrack/netfilter off -----------------------------------------

  # Firewall off + conntrack module load blocked. Bootstrap LAN is trusted;
  # provisioned hosts will gate management access at the switch/VLAN. If a
  # provisioned host needs targeted ingress filtering later, prefer
  # nftables direct rules without conntrack state-tracking.
  networking.firewall.enable = false;
  boot.blacklistedKernelModules = [
    "nf_conntrack"
    "nf_conntrack_ipv4"
    "nf_conntrack_ipv6"
    "nf_nat"
  ];

  # --- W-007: sshd source-IP penalty disabled ---------------------------------

  services.openssh.settings.PerSourcePenalties = "no";

  # --- W-004: sshd pam_systemd session creation off ---------------------------

  # pam_systemd creates/destroys a D-Bus user session per ssh connect; the
  # teardown after non-PTY sessions blocks sshd accept for several minutes.
  security.pam.services.sshd.startSession = lib.mkForce false;

  # --- sshd liveness tuning ---------------------------------------------------

  # Match client-side ServerAliveInterval / ServerAliveCountMax in gibson
  # ~/.ssh/config. Detects a wedged client in ~3min instead of leaving a
  # zombie session pinning resources for default ClientAliveCountMax * 60s.
  services.openssh.settings = {
    ClientAliveInterval = 60;
    ClientAliveCountMax = 3;
  };

  # --- NIC offload disable on end0 (Pi5) and eth0 (Pi4) -----------------------

  # Pi vendor kernels have a long history of TSO/GSO/GRO/checksum-offload
  # bugs that corrupt or drop frames under specific patterns, leading to
  # retransmit storms or stuck TX rings. Disabling offloads moves the work
  # to CPU (cheap on Pi5 quad-core) and removes the buggy code paths.
  # Implemented as a oneshot service so it runs after NIC interfaces appear,
  # without depending on networkd/networkmanager specifics.
  systemd.services.hlc-nic-offload-tame = {
    description = "Disable NIC hardware offloads on bcm2712/bcmgenet";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.ethtool ];
    script = ''
      for nic in end0 eth0; do
        if [ -e "/sys/class/net/$nic" ]; then
          echo "Taming offloads on $nic"
          ethtool -K "$nic" tso off gso off gro off lro off || true
          ethtool -K "$nic" tx-checksum-ip-generic off rx-checksum off || true
          # EEE (link power-save) has caused brief link stalls under burst
          # on bcm2712. Off; trivial energy cost on a wired LAN node.
          ethtool --set-eee "$nic" eee off 2>/dev/null || true
        fi
      done
    '';
  };
}
