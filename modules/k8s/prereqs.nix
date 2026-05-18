{ lib, pkgs, ... }:
let
  k8s-health-check = pkgs.writeShellScriptBin "k8s-health-check" ''
    PASS=0
    FAIL=0
    check() {
      local label="$1"; shift
      if "$@" >/dev/null 2>&1; then
        echo "  PASS  $label"
        PASS=$((PASS + 1))
      else
        echo "  FAIL  $label"
        FAIL=$((FAIL + 1))
      fi
    }

    check_val() {
      local label="$1" expected="$2"; shift 2
      local actual
      actual=$("$@" 2>/dev/null)
      if [ "$actual" = "$expected" ]; then
        echo "  PASS  $label ($actual)"
        PASS=$((PASS + 1))
      else
        echo "  FAIL  $label (expected $expected, got $actual)"
        FAIL=$((FAIL + 1))
      fi
    }

    echo "k8s prerequisite health check — $(hostname)"
    echo "================================================"

    echo ""
    echo "Binaries:"
    check "k3s binary"   k3s --version
    check "kubectl"      kubectl version --client
    check "k9s"          k9s version --short
    check "helm"         helm version --short

    echo ""
    echo "Service state:"
    check_val "k3s unit enabled" "linked" systemctl is-enabled k3s
    check_val "k3s unit stopped" "inactive" systemctl is-active k3s

    echo ""
    echo "Kernel modules:"
    check "br_netfilter loaded"  grep -q br_netfilter /proc/modules
    check "overlay loaded"       grep -q overlay /proc/modules
    check "ip_tables loaded"     grep -q ip_tables /proc/modules

    echo ""
    echo "Sysctls:"
    check_val "net.ipv4.ip_forward" "1" sysctl -n net.ipv4.ip_forward
    check_val "net.bridge.bridge-nf-call-iptables" "1" sysctl -n net.bridge.bridge-nf-call-iptables
    check_val "net.bridge.bridge-nf-call-ip6tables" "1" sysctl -n net.bridge.bridge-nf-call-ip6tables

    echo ""
    echo "cgroups:"
    check "cgroups v2 mounted"  test -f /sys/fs/cgroup/cgroup.controllers

    echo ""
    echo "Storage:"
    check_val "no cluster state" "" sh -c "ls /var/lib/rancher/k3s/ 2>/dev/null"

    echo ""
    echo "================================================"
    echo "Results: $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
  '';
in
{
  # k3s OS-level prerequisites: binary + systemd unit installed, but service
  # not started. Follow-on cluster-bootstrap spec drops config and flips
  # wantedBy back to [ "multi-user.target" ].
  services.k3s.enable = true;

  # Enabled-but-stopped: install the unit without activating it.
  # Cluster bootstrap spec will remove this override when ready.
  systemd.services.k3s.wantedBy = lib.mkForce [ ];

  # Container runtime kernel modules
  boot.kernelModules = [ "br_netfilter" "overlay" "ip_tables" ];

  # Networking prerequisites for pod-to-pod and service traffic
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };

  # cgroups v2 resource accounting is enabled by default in NixOS 25.11

  # Note: k9s, kubectl, and kubernetes-helm are already provided by
  # modules/shell/utilities.nix — not duplicated here.
  environment.systemPackages = [ k8s-health-check ];
}
