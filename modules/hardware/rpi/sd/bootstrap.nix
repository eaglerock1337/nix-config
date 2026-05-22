{ operatorPubkeys, lib, pkgs, ... }:

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
    # 2GB: nixos-install stages large NARs (kernel, firmware) through /tmp;
    # 512MB caused download exhaustion and provision timeouts.
    options = [ "size=2G" "mode=1777" "nosuid" "nodev" ];
  };

  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=128M" "mode=1777" "nosuid" "nodev" ];
  };

  # W-002: passwordless wheel for bob — required for `nixos-rebuild switch
  # --target-host bob@<ip> --use-remote-sudo` canary path.
  security.sudo.wheelNeedsPassword = false;

  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = operatorPubkeys;
  };

  # W-010: root SSH key required for nixos-anywhere --phases disko,install,reboot.
  # Pi vendor kernel kexec fails ("CPUs are stuck in the kernel" — vc4/brcmfmac
  # drivers lack quiesce callbacks). Without kexec, nixos-anywhere installs its
  # temp key to root directly. Bootstrap image is throwaway; trusted LAN; key-only.
  users.users.root.openssh.authorizedKeys.keys = operatorPubkeys;
}
