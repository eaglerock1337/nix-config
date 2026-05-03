{ operatorPubkey, lib, pkgs, ... }:

{
  imports = [ ./recovery-utils.nix ];

  networking.hostName = lib.mkDefault "hlc-sd-bootstrap";
  system.stateVersion = "25.11";
  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # pam_systemd creates/destroys D-Bus user sessions on every SSH connect;
  # teardown after non-PTY sessions blocks sshd accept for several minutes.
  security.pam.services.sshd.startSession = lib.mkForce false;

  # W-006: nf_conntrack TCP state machine corrupted by SSH session teardown in
  # Pi5 vendor kernel 6.12.47 — disables TCP (both directions) while ICMP
  # works; bootstrap image on trusted private LAN has no need for a firewall.
  # Firewall off alone left conntrack module loadable; blacklist forces it out.
  networking.firewall.enable = false;
  boot.blacklistedKernelModules = [
    "nf_conntrack"
    "nf_conntrack_ipv4"
    "nf_conntrack_ipv6"
    "nf_nat"
  ];

  # IPv6 off: bootstrap LAN is v4-only; eliminates v6 conntrack/netfilter paths
  # as a possible hang vector and shrinks attack surface.
  networking.enableIPv6 = false;
  boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = 1;
  boot.kernel.sysctl."net.ipv6.conf.default.disable_ipv6" = 1;

  # Logs in RAM: removes SD card I/O latency as a hang vector for sshd auth
  # path (which fsyncs session events). Bootstrap image is throwaway; no need
  # for persistent journal.
  services.journald.storage = "volatile";
  services.journald.extraConfig = ''
    RuntimeMaxUse=64M
  '';

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=512M" "mode=1777" "nosuid" "nodev" ];
  };

  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=128M" "mode=1777" "nosuid" "nodev" ];
  };

  # W-002: passwordless wheel for bob — required for `nixos-rebuild switch
  # --target-host bob@<ip> --use-remote-sudo` canary path. Bootstrap-scoped
  # here; provisioned-host scope lands in modules/users/operator.nix at Phase 6.
  security.sudo.wheelNeedsPassword = false;

  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };

  # --- Hang watcher: auto-capture diagnostics when SSH port becomes unreachable ---
  # The Pi5 SSH hang is transient (5-10 min self-recovery). This timer captures
  # triage data automatically even if the operator isn't watching. Sentinel file
  # prevents repeated captures within the same hang window.
  systemd.services.hlc-hang-watcher = {
    description = "Detect SSH port hang and auto-capture diagnostics";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.bash pkgs.coreutils ];
    script = ''
      SENTINEL="/tmp/hlc-hang-active"

      if timeout 5 bash -c 'echo > /dev/tcp/127.0.0.1/22' 2>/dev/null; then
        rm -f "$SENTINEL"
        exit 0
      fi

      # Port unreachable — capture once per hang window
      if [ -f "$SENTINEL" ]; then
        exit 0
      fi

      touch "$SENTINEL"
      echo "$(date -Iseconds): SSH port 22 unreachable — capturing diagnostics"
      /run/current-system/sw/bin/hlc-triage
    '';
  };

  systemd.timers.hlc-hang-watcher = {
    description = "Check SSH port reachability every 30s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "60s";
      OnUnitActiveSec = "30s";
    };
  };
}
