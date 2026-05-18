# Shared HLC option declarations (T033).
# Imported by both default.nix (full config) and provision.nix (minimal config)
# to avoid NixOS duplicate-option declaration errors when both flake outputs
# evaluate against the same host configuration.

{ lib, ... }: {
  options.hlc = {
    prompt.glyph = lib.mkOption {
      type = lib.types.str;
      default = "☁️ 🏔️ ☁️";
      description = ''
        Full HLC PS1 glyph sequence. Default is emoji-presentation (U+FE0F
        selectors): cloud + snow-capped mountain + cloud. Per-host fallback
        (`hosts/hlc-<NNN>/configuration.nix`) sets `"☁⛰︎☁"` (text-presentation,
        U+FE0E selectors) for terminals where emoji renders double-width and
        misaligns the prompt.
      '';
    };

    # Disko device options consumed by disko/rpi{4,5}.nix
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
}
