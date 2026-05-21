# Gibson — AMD Ryzen 9 5950X / NVIDIA RTX 3080 desktop
# Unfree: nvidia-x11, nvidia-settings required for RTX 3080 proprietary driver (FR-012)

{ operatorPubkeys, ... }:

{
  imports = [
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/workstation/grub.nix
    ../../modules/nixos/workstation/desktop-ui.nix
    ../../modules/nixos/workstation/gaming.nix
    ../../modules/hardware/gibson.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "gibson";

  system.operator = {
    name = "eaglerock";
    pubkeys = operatorPubkeys;
    description = "Peter Marks";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
  };

  # NVIDIA proprietary driver requires unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem ((pkg.pname or (pkg.name or ""))) [
      "nvidia-x11"
      "nvidia-settings"
    ];

  system.stateVersion = "25.11";
}
