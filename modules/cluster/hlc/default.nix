{ lib, ... }: {
  imports = [
    ../common.nix
    ./hosts.nix
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
        description = "First USB storage device path (by-id); filled before provisioning.";
      };
      usbDevice1 = lib.mkOption {
        type = lib.types.str;
        default = "PLACEHOLDER";
        description = "Second USB storage device path (by-id); filled before provisioning.";
      };
      nvmeDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "NVMe device path (by-id); null on Pi 4 nodes (no NVMe).";
      };
    };
  };

  config = {
    # networking.fqdn is auto-derived as "${hostName}.${domain}" — do NOT assign directly
    networking.domain = "marks.dev";
  };
}
