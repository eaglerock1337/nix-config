{ lib, ... }: {
  imports = [
    ../common.nix
    ./hosts.nix
    ./raid-fallback.nix
  ];

  options.hlc = {
    motd.banner = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "HLC ASCII banner displayed in MOTD (set in hlc/default.nix for the cluster).";
    };

    # Phase 5: disko/rpi{4,5}.nix will consume these to build the disk layout.
    # Declared here so Phase 4 host configs can set placeholder values and dry-run.
    disko = {
      usbDevice0 = lib.mkOption {
        type = lib.types.str;
        default = "PLACEHOLDER";
        description = "First USB storage device path (by-path); filled before provisioning.";
      };
      usbDevice1 = lib.mkOption {
        type = lib.types.str;
        default = "PLACEHOLDER";
        description = "Second USB storage device path (by-path); filled before provisioning.";
      };
      nvmeDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "NVMe device path (by-path); null on Pi 4 nodes (no NVMe).";
      };
      skipNvmeFormat = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Exclude NVMe from disko schema (formatting only). Used by 'make reprovision' to preserve /srv cluster data. Install phase always uses full config.";
      };
    };
  };

  config = {
    # networking.fqdn is auto-derived as "${hostName}.${domain}" — do NOT assign directly
    networking.domain = "marks.dev";

    # Allow bob to receive nix store paths via `nix copy` from gibson (W-012).
    # gibson has no nixos-rebuild; deployment uses `nix build` + `nix copy --to
    # ssh-ng://bob@<node>` + remote `switch-to-configuration`. trusted-users
    # grants store write access through the nix daemon.
    nix.settings.trusted-users = [ "root" "bob" ];
  };
}
