# DECOMMISSIONED-SET — currently Debian. Do NOT flash or nixos-rebuild switch
# this host. See constitution v1.1.0 § Cluster Topology.
{ operatorPubkey, ... }: {
  raspberry-pi-nix.board = "bcm2711";
  networking.hostName = "hlc-403";
  networking.useDHCP = true;
  services.openssh.enable = true;
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };
  security.sudo.wheelNeedsPassword = false; # WORKAROUNDS W-002
  system.stateVersion = "25.11";
}
