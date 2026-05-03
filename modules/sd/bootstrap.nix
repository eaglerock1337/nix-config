{ operatorPubkey, lib, ... }:

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
}

sudo ethtool -k end0 | grep -E "tcp-segmentation|generic-segmentation|generic-receive|large-receive"

nix --extra-experimental-features 'nix-command flakes' flake show github:nvmd/nixos-raspberrypi 2>&1 | grep -iE "kernel|linux"   