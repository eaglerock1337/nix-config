{ pkgs, lib, operatorPubkey, ... }: {
  raspberry-pi-nix.board = "bcm2712";
  networking.hostName = "hlc-501";
  networking.useDHCP = true;
  # Drop [success=merge] for group NSS: without systemd-userdbd the D-Bus call
  # behind nss-systemd is slow and intermittently hangs sudo's group membership
  # check (wheel). Files is sufficient; systemd is fallback for dynamic users only.
  system.nssDatabases.group = lib.mkForce [ "files" "systemd" ];
  services.openssh.enable = true;
  # NOTE: PasswordAuthentication left at NixOS default (true) per
  # WORKAROUNDS W-003 — short-term fallback so a misconfigured authorized_keys
  # cannot brick a headless node. Closes at T104 (Phase 7f SSH hardening).
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };
  security.sudo.wheelNeedsPassword = false; # WORKAROUNDS W-002
  environment.systemPackages = with pkgs; [
    git
    htop
    jq
    ripgrep
    tmux
  ];
  system.stateVersion = "25.11";
}
