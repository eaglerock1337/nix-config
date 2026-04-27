{ pkgs, operatorPubkey, ... }: {
  raspberry-pi-nix.board = "bcm2712";
  networking.hostName = "hlc-502";
  networking.useDHCP = true;
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
