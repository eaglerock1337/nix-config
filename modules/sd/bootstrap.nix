{ operatorPubkey, lib, pkgs, ... }:

{
  imports = [ ./recovery-utils.nix ];

  networking.hostName = lib.mkDefault "hlc-sd-bootstrap";
  system.stateVersion = "25.11";
  networking.useDHCP = true;

  # Required for nixos-anywhere disko to create mdadm RAID arrays (W-010).
  # Without this, udev lacks the mdadm rules to create /dev/md/<name> symlinks
  # after mdadm --create, causing disko to fail with "timeout waiting for /dev/md/usb-raid".
  boot.swraid.enable = true;
  # Silence "Neither MAILADDR nor PROGRAM" eval warning; mdmon needs one set.
  # Bootstrap has no mail infra; route to root as a no-op.
  boot.swraid.mdadmConf = "MAILADDR root";

  services.openssh = {
    enable = true;
    # Bootstrap-only: provisioned hosts retain default password auth posture
    # until W-003 closes in Phase 6 SSH hardening.
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # IPv6 off: bootstrap LAN is v4-only; shrinks attack surface.
  networking.enableIPv6 = false;

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
