# Shared HLC option declarations
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
    # Class-level defaults set in modules/hardware/rpi{4,5}.nix via lib.mkDefault
    disko = {
      usbDevice0 = lib.mkOption {
        type = lib.types.str;
        description = "First USB storage device path (by-path). Class default set in hardware module.";
      };
      usbDevice1 = lib.mkOption {
        type = lib.types.str;
        description = "Second USB storage device path (by-path). Class default set in hardware module.";
      };
      nvmeDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "NVMe device path; null on Pi 4 (no NVMe). Pi 5 default set in hardware module.";
      };
      skipNvmeFormat = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Exclude NVMe from disko schema (formatting only). Used by 'make reprovision' to preserve /srv cluster data. Install phase always uses full config.";
      };
    };
  };
}
