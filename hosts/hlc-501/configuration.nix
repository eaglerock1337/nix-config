# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, ... }:

{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.sd-image
    # T011: SD image closure contains only modules/sd/bootstrap.nix (US1/FR-003)
    ../../modules/sd/bootstrap.nix
  ];

  networking.hostName = "hlc-501";

  system.stateVersion = "25.11";
}
