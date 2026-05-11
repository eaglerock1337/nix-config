{ config, lib, operatorPubkeys, ... }: {
  imports = [
    ../common.nix
    ./hosts.nix
    ./raid-fallback.nix
  ];

  options.hlc = {
    prompt.glyph = lib.mkOption {
      type = lib.types.str;
      default = "☁️🏔️☁️";
      description = ''
        Full HLC PS1 glyph sequence. Default is emoji-presentation (U+FE0F
        selectors): cloud + snow-capped mountain + cloud. Per-host fallback
        (`hosts/hlc-<NNN>/configuration.nix`) sets `"☁⛰︎☁"` (text-presentation,
        U+FE0E selectors) for terminals where emoji renders double-width and
        misaligns the prompt.
      '';
    };

    # Phase 5: disko/rpi{4,5}.nix consume these to build the disk layout.
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
    nix.settings.trusted-users = [ "root" "bob" ];

    # HLC MOTD content (cluster.motd mechanism in modules/cluster/motd.nix).
    # Banner + quote sourced verbatim from sibling .txt files so the displayed
    # indent is preserved (Nix `''` indent-stripping would otherwise flatten it).
    cluster.motd.banner = builtins.readFile ./motd-banner.txt;
    cluster.motd.quote = builtins.readFile ./motd-quote.txt;

    # Wire HLC glyph into the generic cluster prompt mechanism
    cluster.prompt.glyph = config.hlc.prompt.glyph;

    # HLC cluster operator
    system.operator = {
      name = "bob";
      pubkeys = operatorPubkeys;
      description = "HLC cluster operator";
    };

    # Home-manager bindings for the operator
    home-manager.extraSpecialArgs = { };
    home-manager.users.bob = import ../../../home/bob.nix;
  };
}
