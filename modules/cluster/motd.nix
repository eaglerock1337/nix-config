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
    # Create /etc/motd directly. `users.motd` is avoided because in current
    # nixpkgs it only writes a nix-store file and wires pam_motd — it does NOT
    # produce /etc/motd, and the pam_motd path was observed not displaying on
    # sshd pubkey login (linux-pam 1.7.1). PrintMotd reads /etc/motd directly.
    environment.etc."motd".text = ''
      ${cfg.banner}

            Cluster node: ${config.networking.fqdn}

      ${cfg.quote}
    '';

    services.openssh.settings.PrintMotd = true;
  };
}
