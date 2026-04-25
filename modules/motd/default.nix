# Parameterized MOTD module.
# Writes /etc/motd at build time using NixOS's environment.etc mechanism.
# SSH and PAM display this file automatically on login — no systemd service needed.
# Cluster-specific values (asciiArt, tagline) are set by the cluster's own motd module,
# e.g. modules/cluster/hlc/motd.nix.
{ config, lib, ... }:

let
  cfg = config.cluster.motd;
  inherit (lib) mkEnableOption mkOption types optionalString mkIf;
in {
  options.cluster.motd = {
    enable = mkEnableOption "cluster MOTD displayed on SSH login";

    clusterName = mkOption {
      type = types.str;
      default = "";
      description = "Human-readable cluster name shown in the MOTD.";
    };

    asciiArt = mkOption {
      type = types.lines;
      default = "";
      description = "Multi-line ASCII art banner for the cluster.";
    };

    tagline = mkOption {
      type = types.str;
      default = "";
      description = "Quote or tagline displayed below the banner.";
    };

    attribution = mkOption {
      type = types.str;
      default = "";
      description = "Attribution line for the tagline (e.g. '~ Bob Ross').";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."motd".text = ''
      ${optionalString (cfg.asciiArt != "") cfg.asciiArt}
      ${optionalString (cfg.clusterName != "") "  ${cfg.clusterName}"}
        ${config.networking.hostName}
      ${optionalString (cfg.tagline != "") ""}
      ${optionalString (cfg.tagline != "") "  \"${cfg.tagline}\""}
      ${optionalString (cfg.attribution != "") "  ${cfg.attribution}"}
    '';
  };
}
