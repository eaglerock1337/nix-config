# Option-driven operator user (FR-020, closes W-001 inline-host pattern).
# A single `system.operator = { name; pubkeys; ... }` config materializes the
# operator account uniformly across workstations and clusters. Each host context
# (HLC, silicon, future Ecto-1) sets its own values.
#
# Key-only SSH hardening (W-003) and passwordless wheel (W-002) are applied
# unconditionally — they describe how the operator interacts with this host,
# not whether the operator exists.

{ config, lib, pkgs, ... }:

let
  cfg = config.system.operator;
in {
  options.system.operator = {
    name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Operator login name. Host sets this to materialize the operator account
        (e.g. "bob" on HLC, "eaglerock" on silicon, future "slimer" on Ecto-1).
        Leave null on hosts that do not need an operator user.
      '';
    };

    pubkeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for the operator account.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "wheel" ];
      description = ''
        Supplementary groups for the operator. Defaults to wheel (sudo).
        Workstation operators typically add networkmanager and docker.
      '';
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Free-text user description (GECOS).";
    };
  };

  config = lib.mkMerge [
    # Operator account materializes only when a name is set.
    (lib.mkIf (cfg.name != null) {
      users.users.${cfg.name} = {
        isNormalUser = true;
        extraGroups = cfg.extraGroups;
        openssh.authorizedKeys.keys = cfg.pubkeys;
        description = cfg.description;
        shell = pkgs.bash;
      };
    })

    # Universal hardening — applies whether or not an operator is named.
    {
      # W-002: passwordless wheel during cluster transition; remove once
      # sops-nix secrets management lands (feature 002).
      security.sudo.wheelNeedsPassword = false;

      # W-003 closed: key-only SSH enforced post-provisioning.
      services.openssh.settings.PasswordAuthentication = false;
      services.openssh.settings.KbdInteractiveAuthentication = false;
    }
  ];
}
