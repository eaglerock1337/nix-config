{ config, pkgs, lib, ... }:

let
  hlc-recover = pkgs.writeShellScriptBin "hlc-recover"
    (import ../../../nixos/server/hlc/hlc-recover-script.nix {
      hostname = config.networking.hostName;
    });

  # Full diagnostic capture script for triage during network hangs or other
  # incidents. Run manually from a live SSH session, or automatically via
  # the hlc-hang-watcher timer in bootstrap.nix.
  hlc-triage = let
    path = lib.makeBinPath (with pkgs; [
      coreutils
      ethtool
      gawk
      gnugrep
      iproute2
      lsof
      procps
      systemd
      tcpdump
      util-linux
    ]);
  in pkgs.writeShellScriptBin "hlc-triage" ''
    export PATH="${path}:$PATH"

    OUTDIR="/tmp/hlc-triage/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$OUTDIR"

    echo "=== HLC Triage Capture ==="
    echo "Host: $(hostname)"
    echo "Time: $(date -Iseconds)"
    echo "Output: $OUTDIR"
    echo ""

    capture() {
      local label="$1"; shift
      echo "  capturing $label ..."
      "$@" > "$OUTDIR/$label.txt" 2>&1 || true
    }

    # --- Network state ---
    capture "ss-tan"            ss -tan
    capture "ss-uan"            ss -uan
    capture "ip-addr"           ip addr
    capture "ip-route"          ip route
    capture "ip-link-stats"     ip -s link show
    capture "sockstat"          cat /proc/net/sockstat
    capture "proc-net-tcp"      cat /proc/net/tcp

    # --- NIC diagnostics (Pi5 = end0, Pi4 = eth0) ---
    for nic in end0 eth0; do
      if [ -e "/sys/class/net/$nic" ]; then
        capture "ethtool-$nic"          ethtool "$nic"
        capture "ethtool-stats-$nic"    ethtool -S "$nic"
        capture "ethtool-features-$nic" ethtool -k "$nic"
      fi
    done

    # --- SSH / dropbear / sshd state ---
    capture "ps-ssh"            ps -eo pid,ppid,stat,wchan:32,comm --sort=pid
    capture "journal-dropbear"  journalctl -u dropbear -n 100 --no-pager
    capture "journal-sshd"      journalctl -u sshd -n 100 --no-pager
    capture "lsof-port22"       lsof -i :22

    # --- Kernel ---
    capture "dmesg"             dmesg -T
    capture "interrupts"        cat /proc/interrupts
    capture "softirqs"          cat /proc/softirqs
    capture "softnet-stat"      cat /proc/net/softnet_stat

    # --- System ---
    capture "uptime"            uptime
    capture "free"              free -h
    capture "vmstat"            cat /proc/vmstat
    capture "mount"             mount
    capture "uname"             uname -a

    # --- Summary ---
    echo ""
    NFILES=$(find "$OUTDIR" -type f | wc -l)
    echo "Captured $NFILES files to $OUTDIR"

    # Quick-look: show TCP socket state distribution
    echo ""
    echo "--- TCP socket state summary ---"
    ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn || true

    # Quick-look: any D-state or zombie processes
    echo ""
    echo "--- D-state / zombie processes ---"
    ps -eo pid,stat,comm | awk '$2 ~ /^[DZ]/' || echo "(none)"
  '';
in
{
  environment.systemPackages = with pkgs; [
    curl          # HTTP fetches
    dmidecode     # hardware info
    dnsutils      # DNS diagnostics; provides dig/nslookup
    e2fsprogs     # ext4 filesystem tools
    ethtool       # NIC diagnostics and offload control
    git           # repo access
    gptfdisk      # GPT partition manipulation; provides sgdisk
    htop          # process monitor
    iproute2      # ip command
    lsof          # open file/socket listing
    util-linux    # block device tools; provides lsblk
    mdadm         # RAID management
    parted        # partition editor
    pciutils      # PCIe device info; provides lspci
    strace        # syscall tracer for process-level debugging
    smartmontools # SMART disk health; provides smartctl
    sysstat       # sar/iostat/mpstat for system performance
    tcpdump       # network packet capture
    tmux          # terminal multiplexer
    usbutils      # USB device info; provides lsusb
    vim           # editor
    xfsprogs      # XFS filesystem tools
    hlc-recover   # guided RAID/SD recovery (see let block above)
    hlc-triage    # one-shot diagnostic capture (see let block above)
  ];
}
