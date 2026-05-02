{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # T007: nvmd/nixos-raspberrypi replaces archived nix-community/raspberry-pi-nix
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    # T010: disko for declarative disk layout (Phase 5 / US3)
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # T011: nixos-anywhere for one-shot remote provisioning (Phase 5 / US3)
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    # T012: sops-nix deferred per W-002; input added now for flake hygiene
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixos-raspberrypi, nixos-hardware, disko, nixos-anywhere, sops-nix, ... } @ inputs:
  let
    system = "x86_64-linux";

    # T008: operator's gibson SSH public key — used in bootstrap + per-host configs
    operatorPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3NGjPn92I1/n7pBTne/0aw0xVvgebFriN1UMKcEQagG3QzmM/4+zj001UGNKFK7FOlnTx6b8dz2mEC/ejYFG6R2Vtd6coxShjQDL2Nw3B/FMfky+jOBQ7viyODEiPhQlrO2FrQcd0BgjzHPvH0qtu12Ej2bo27abkIpyCEJyLf/xFKIyZ/RyFWaF8FOA4tpXpXvNa73QijvymMk2gY2HuLQVGYGPAVsLBEUbmAV7oN3inPcbawmjAgV5X23AoMr9F5pZbxdmZ61FUwWvaBjRdTopgfkI1RXZ52P27CJTjC3ndmlSgfV2Ht1iQ9VQmY5ShxFET9Wr6jz eaglerock@gibson";

    unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem ((pkg.pname or (pkg.name or ""))) [
            "claude-code"
          ];
      };
    };

    # T009: thin mkHlcNode wrapper around nixpkgs.lib.nixosSystem.
    # Composes: home-manager module and the per-host configuration.nix.
    # Pi-family selection is handled by the nvmd modules imported in each per-host
    # configuration.nix (raspberry-pi-{4,5}.base). nixos-hardware Pi modules are not
    # used — they conflict with nvmd's boot.kernelPackages and add nothing a headless
    # nvmd-based node doesn't already get from the base module.
    # NOT included here: nvmd cluster-common modules (raspberry-pi base + sd-image) —
    # those belong in modules/cluster/common.nix per FR-006, landing in T024 (Phase 4).
    # NOT included here: home-manager.users.bob wiring — deferred to T080 (Phase 6/US4).
    mkHlcNode = { hostPath }:
      # Using nixos-raspberrypi.lib.nixosSystem (wraps nixpkgs.lib.nixosSystem) so that
      # nvmd's package overlays (raspberrypi-utils, vendor kernel/firmware, etc.) are
      # applied automatically. It also injects nixos-raspberrypi into specialArgs, which
      # the nvmd modules reference directly.
      nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs operatorPubkey; };
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
          }
          hostPath
        ];
      };
  in {
    nixosConfigurations = {
      silicon = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self nixpkgs nixpkgs-unstable home-manager; };
        modules = [
          ./hosts/silicon/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit unstable; };
            home-manager.users.eaglerock = import ./home/eaglerock.nix;
            # Back up conflicting files instead of failing
            home-manager.backupFileExtension = "backup";
          }
          {
            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem ((pkg.pname or (pkg.name or ""))) [
                "claude-code"
              ];
          }
        ];
      };

      # Pi 5 work-set (hlc-501..508) — provisioned nodes
      hlc-501 = mkHlcNode { hostPath = ./hosts/hlc-501/configuration.nix; };
      hlc-502 = mkHlcNode { hostPath = ./hosts/hlc-502/configuration.nix; };
      hlc-503 = mkHlcNode { hostPath = ./hosts/hlc-503/configuration.nix; };
      hlc-504 = mkHlcNode { hostPath = ./hosts/hlc-504/configuration.nix; };
      hlc-505 = mkHlcNode { hostPath = ./hosts/hlc-505/configuration.nix; };
      hlc-506 = mkHlcNode { hostPath = ./hosts/hlc-506/configuration.nix; };
      hlc-507 = mkHlcNode { hostPath = ./hosts/hlc-507/configuration.nix; };
      hlc-508 = mkHlcNode { hostPath = ./hosts/hlc-508/configuration.nix; };

      # Pi 4 work-set — hlc-401 provisioned; hlc-402..404 deferred (config-only per Constitution)
      hlc-401 = mkHlcNode { hostPath = ./hosts/hlc-401/configuration.nix; };
      hlc-402 = mkHlcNode { hostPath = ./hosts/hlc-402/configuration.nix; };
      hlc-403 = mkHlcNode { hostPath = ./hosts/hlc-403/configuration.nix; };
      hlc-404 = mkHlcNode { hostPath = ./hosts/hlc-404/configuration.nix; };

    };
  };
}
