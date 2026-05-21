{ operatorPubkeys, ... }:

{
  imports = [
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/workstation/grub.nix
    ../../modules/nixos/workstation/desktop-ui.nix
    ../../modules/nixos/workstation/gaming.nix
    ../../modules/hardware/x1-carbon.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "silicon";

  system.operator = {
    name = "eaglerock";
    pubkeys = operatorPubkeys;
    description = "Peter Marks";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
  };

  # See `man configuration.nix` before changing this — it pins stateful data
  # locations to the release version that first installed this system.
  system.stateVersion = "25.05";
}
