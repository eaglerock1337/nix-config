# Option-driven operator user
# A single `system.operator = { name; pubkeys; ... }` config materializes the
# operator account uniformly across workstations and clusters. Each host context
# (HLC, silicon, Ecto-1) sets its own values.
#
# This module ONLY generates the user account. Cluster-only security policy
# (key-only SSH, passwordless wheel) lives in modules/cluster/common.nix.

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
        (e.g. "bob" on HLC, "eaglerock" on silicon, "slimer" on Ecto-1).
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

  config = lib.mkIf (cfg.name != null) {
    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = cfg.extraGroups;
      openssh.authorizedKeys.keys = cfg.pubkeys;
      description = cfg.description;
      shell = pkgs.bash;
    };
  };
}
