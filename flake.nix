{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    # T012: sops-nix deferred per W-002; input added now for flake hygiene
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixos-raspberrypi, nixos-hardware, disko, nixos-anywhere, sops-nix, ... } @ inputs:
  let
    system = "x86_64-linux";

    # Operator SSH public keys — all keys that should access cluster nodes
    operatorPubkeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3NGjPn92I1/n7pBTne/0aw0xVvgebFriN1UMKcEQagG3QzmM/4+zj001UGNKFK7FOlnTx6b8dz2mEC/ejYFG6R2Vtd6coxShjQDL2Nw3B/FMfky+jOBQ7viyODEiPhQlrO2FrQcd0BgjzHPvH0qtu12Ej2bo27abkIpyCEJyLf/xFKIyZ/RyFWaF8FOA4tpXpXvNa73QijvymMk2gY2HuLQVGYGPAVsLBEUbmAV7oN3inPcbawmjAgV5X23AoMr9F5pZbxdmZ61FUwWvaBjRdTopgfkI1RXZ52P27CJTjC3ndmlSgfV2Ht1iQ9VQmY5ShxFET9Wr6jz eaglerock@gibson"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK+Z0E+vIXJMcVO0Pv81vZNHoF4JuS08r2t7rAEWhm4 eaglerock@nixos"
    ];

    unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem ((pkg.pname or (pkg.name or ""))) [
            "claude-code"
          ];
      };
    };

    # Thin mkHlcNode wrapper — provisioned nixosConfiguration for a cluster node.
    # SD bootstrap images are separate derivations built by mkHlcBootstrap below.
    mkHlcNode = { hostPath, extraModules ? [] }:
      # Using nixos-raspberrypi.lib.nixosSystem so nvmd's overlays (vendor kernel,
      # firmware, raspberrypi-utils) and specialArgs injection apply automatically.
      nixos-raspberrypi.lib.nixosSystem {
        specialArgs = {
          inherit inputs operatorPubkeys;
          clusterModule = ./modules/cluster/hlc/default.nix;
        };
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
          }
          # disko NixOS module provides disko.devices option; imported here
          # so hardware modules (rpi4.nix, rpi5.nix) can set disk layouts.
          disko.nixosModules.disko
          hostPath
        ] ++ extraModules;
      };

    # Provision — minimal builder — small closure for nixos-anywhere stage2.
    # No home-manager; passes clusterModule = provision.nix via specialArgs so the
    # host config imports the minimal cluster module instead of the full one.
    mkHlcProvision = { hostPath, extraModules ? [] }:
      nixos-raspberrypi.lib.nixosSystem {
        specialArgs = {
          inherit inputs operatorPubkeys;
          clusterModule = ./modules/cluster/hlc/provision.nix;
        };`
        modules = [
          disko.nixosModules.disko
          hostPath
        ] ++ extraModules;
      };

    # mkHlcBootstrap — builds a minimal SD bootstrap image for a single node.
    # Hostname is the only per-node differentiator; everything else is shared.
    # sd-image module lives here only, never in provisioned nixosConfigurations.
    mkHlcBootstrap = { hostname, piModule }:
      (nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs operatorPubkeys; };
        modules = [
          piModule
          inputs.nixos-raspberrypi.nixosModules.sd-image
          ./modules/sd/bootstrap.nix
          { networking.hostName = hostname; }
        ];
      }).config.system.build.sdImage;

    # Host lists — used to generate SD image packages for all 12 nodes.
    # Pi 4: hlc-401..404 (4 nodes); Pi 5: hlc-501..508 (8 nodes).
    pi4Hosts = [ "hlc-401" "hlc-402" "hlc-403" "hlc-404" ];
    pi5Hosts = map (n: "hlc-5${nixpkgs.lib.fixedWidthNumber 2 n}") (nixpkgs.lib.range 1 8);

    # mkSdImages — generate { "<host>-sdImage" = <derivation>; } for a list of hosts.
    mkSdImages = piModule: hosts:
      builtins.listToAttrs (map (h: {
        name = "${h}-sdImage";
        value = mkHlcBootstrap { hostname = h; inherit piModule; };
      }) hosts);
  in {
    nixosConfigurations = {
      silicon = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self nixpkgs nixpkgs-unstable home-manager operatorPubkeys; };
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

      # Pi 5 work-set (hlc-501..508)
      hlc-501 = mkHlcNode { hostPath = ./hosts/hlc-501/configuration.nix; };
      hlc-502 = mkHlcNode { hostPath = ./hosts/hlc-502/configuration.nix; };
      hlc-503 = mkHlcNode { hostPath = ./hosts/hlc-503/configuration.nix; };
      hlc-504 = mkHlcNode { hostPath = ./hosts/hlc-504/configuration.nix; };
      hlc-505 = mkHlcNode { hostPath = ./hosts/hlc-505/configuration.nix; };
      hlc-506 = mkHlcNode { hostPath = ./hosts/hlc-506/configuration.nix; };
      hlc-507 = mkHlcNode { hostPath = ./hosts/hlc-507/configuration.nix; };
      hlc-508 = mkHlcNode { hostPath = ./hosts/hlc-508/configuration.nix; };

      # Pi 4 work-set — (hlc-401..404)
      hlc-401 = mkHlcNode { hostPath = ./hosts/hlc-401/configuration.nix; };
      hlc-402 = mkHlcNode { hostPath = ./hosts/hlc-402/configuration.nix; };
      hlc-403 = mkHlcNode { hostPath = ./hosts/hlc-403/configuration.nix; };
      hlc-404 = mkHlcNode { hostPath = ./hosts/hlc-404/configuration.nix; };

    } // builtins.listToAttrs (map (h: {
      # -bare variants: skipNvmeFormat=true — used by 'make reprovision' disko phase only.
      # NVMe excluded from disko formatting; install phase uses full config so fstab is correct.
      name = "${h}-bare";
      value = mkHlcNode {
        hostPath = ./hosts/${h}/configuration.nix;
        extraModules = [{ hlc.disko.skipNvmeFormat = true; }];
      };
    }) pi5Hosts)

    # Provision variants for two-phase provisioning
    # Small closure (no home-manager, toolbox, MOTD, PS1, /etc/hosts, git-clone).
    # Used by nixos-anywhere stage2; full config pushed later via update-node.
    // builtins.listToAttrs (map (h: {
      name = "${h}-provision";
      value = mkHlcProvision { hostPath = ./hosts/${h}/configuration.nix; };
    }) (pi4Hosts ++ pi5Hosts));

    # SD bootstrap images — all 12 nodes (Pi 4: hlc-401..404, Pi 5: hlc-501..508).
    # Hostname is the only per-node differentiator; all else is shared via bootstrap.nix.
    # Built with: nix build .#packages.aarch64-linux.<host>-sdImage
    # (Makefile target: make build-image HOST=<host>)
    packages."aarch64-linux" =
      mkSdImages inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base pi4Hosts //
      mkSdImages inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base pi5Hosts;

  };
}
