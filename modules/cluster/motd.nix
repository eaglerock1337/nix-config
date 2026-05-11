# Cluster-tier MOTD mechanism (FR-018).
# Generic across clusters; cluster-specific banner/quote supplied via options.
# Hostname line is dynamic, interpolated from config.networking.fqdn.

{ config, lib, ... }:

let
  cfg = config.cluster.motd;
in {
  options.cluster.motd = {
    banner = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        ASCII banner shown at SSH login. Per-cluster value (e.g. HLC's
        Bob Ross-themed ASCII art). Set in `modules/cluster/<name>/default.nix`.
      '';
    };

    quote = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Short quote / tagline shown after the hostname line. Per-cluster value.
      '';
    };
  };

  config = {
    # users.motd generates a nix-store file consumed by pam_motd.
    # pam_motd is only enabled when security.pam.services.<svc>.showMotd is true.
    users.motd = ''
      ${cfg.banner}

            Cluster node: ${config.networking.fqdn}

      ${cfg.quote}
    '';

    security.pam.services.sshd.showMotd = true;
  };
}
