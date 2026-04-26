{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    # Phase B: sops-nix for secrets management, disko for declarative disk layout
    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, raspberry-pi-nix, nixos-hardware, ... } @ inputs:
  let
    system = "x86_64-linux";

    unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem ((pkg.pname or (pkg.name or ""))) [
            "claude-code"
          ];
      };
    };

    # Single source of truth for the cluster operator's SSH public key.
    # Passed into every HLC nixosSystem via specialArgs so host configs
    # reference it as `operatorPubkey` instead of duplicating the literal.
    operatorPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3NGjPn92I1/n7pBTne/0aw0xVvgebFriN1UMKcEQagG3QzmM/4+zj001UGNKFK7FOlnTx6b8dz2mEC/ejYFG6R2Vtd6coxShjQDL2Nw3B/FMfky+jOBQ7viyODEiPhQlrO2FrQcd0BgjzHPvH0qtu12Ej2bo27abkIpyCEJyLf/xFKIyZ/RyFWaF8FOA4tpXpXvNa73QijvymMk2gY2HuLQVGYGPAVsLBEUbmAV7oN3inPcbawmjAgV5X23AoMr9F5pZbxdmZ61FUwWvaBjRdTopgfkI1RXZ52P27CJTjC3ndmlSgfV2Ht1iQ9VQmY5ShxFET9Wr6jz eaglerock@gibson";

    # Helper for HLC cluster nodes — wraps nixpkgs.lib.nixosSystem with the
    # raspberry-pi-nix modules and the host's configuration.nix.
    # Path concatenation (./hosts + "/${hostname}/...") produces a Nix path,
    # whereas string interpolation would produce a string and cause eval errors.
    mkHlcNode = { hostname, extraModules ? [] }:
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs operatorPubkey; };
        modules = [
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          (./hosts + "/${hostname}/configuration.nix")
        ] ++ extraModules;
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

      # HLC control-plane nodes (Pi4, bcm2711).
      # nixos-hardware raspberry-pi-4 sets generic-extlinux-compatible.enable=true,
      # which conflicts with raspberry-pi-nix's u-boot bootloader — force it off.
      hlc-401 = mkHlcNode {
        hostname = "hlc-401";
        extraModules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          { boot.loader.generic-extlinux-compatible.enable = nixpkgs.lib.mkForce false; }
        ];
      };
      hlc-402 = mkHlcNode {
        hostname = "hlc-402";
        extraModules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          { boot.loader.generic-extlinux-compatible.enable = nixpkgs.lib.mkForce false; }
        ];
      };
      hlc-403 = mkHlcNode {
        hostname = "hlc-403";
        extraModules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          { boot.loader.generic-extlinux-compatible.enable = nixpkgs.lib.mkForce false; }
        ];
      };
      hlc-404 = mkHlcNode {
        hostname = "hlc-404";
        extraModules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          { boot.loader.generic-extlinux-compatible.enable = nixpkgs.lib.mkForce false; }
        ];
      };

      # HLC worker nodes (Pi5, bcm2712).
      hlc-501 = mkHlcNode {
        hostname = "hlc-501";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-502 = mkHlcNode {
        hostname = "hlc-502";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-503 = mkHlcNode {
        hostname = "hlc-503";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-504 = mkHlcNode {
        hostname = "hlc-504";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-505 = mkHlcNode {
        hostname = "hlc-505";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-506 = mkHlcNode {
        hostname = "hlc-506";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-507 = mkHlcNode {
        hostname = "hlc-507";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
      hlc-508 = mkHlcNode {
        hostname = "hlc-508";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-5 ];
      };
    };
  };
}
