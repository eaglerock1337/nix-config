{ lib, ... }: {
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
}
