# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, operatorPubkey, ... }:

{
  imports = [
    # T013: nvmd raspberry-pi-5.base replaces raspberry-pi-nix.nixosModules.raspberry-pi
    # + raspberry-pi-nix.board = "bcm2712". Board selection is now implicit in the
    # module name. sd-image replaces raspberry-pi-nix.nixosModules.sd-image.
    # Both move to modules/cluster/common.nix in Phase 4 (T024).
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.sd-image
  ];

  networking.hostName = "hlc-501";
  networking.useDHCP = true;

  services.openssh.enable = true;

  # W-001: inline minimal per-host config; shared modules land in Phase 5/US4
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };

  # W-002: passwordless wheel required for nixos-rebuild --target-host --use-remote-sudo
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "25.11";

}
