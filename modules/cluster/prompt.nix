# Cluster-tier PS1 mechanism (FR-017, R-002).
# Generic across clusters; cluster-specific glyph supplied via `cluster.prompt.glyph`.
# HLC sets the glyph through its own `hlc.prompt.glyph` option in modules/cluster/hlc/default.nix.

{ config, lib, ... }:

let
  cfg = config.cluster.prompt;
in {
  options.cluster.prompt = {
    glyph = lib.mkOption {
      type = lib.types.str;
      default = "-";
      description = ''
        Central decoration shown between user@host and cwd in the remote PS1, and
        substituting silicon's `////` separator in the local PS1. Defaults to a
        generic dash; each cluster (HLC, Ecto-1, ...) overrides with its own glyph
        in `modules/cluster/<name>/default.nix`.
      '';
    };
  };

  config = {
    # PS1 emitted via /etc/profile.d so login shells (including non-PTY SSH command
    # execution) pick it up. Cluster nodes do not import the workstation
    # `programs.bash.promptInit`, so this file is the sole PS1 source.
    environment.etc."profile.d/cluster-prompt.sh".text = ''
      # Cluster PS1 (generated from modules/cluster/prompt.nix)

      if [ -n "$SSH_CONNECTION" ]; then
        # Remote form: two-line box-drawing, no color, FQDN.
        # \H = FQDN, \u = user, \w = cwd. Bold only on box-drawing glyphs.
        PS1='\[\e[1m\]┌─╸\[\e[0m\]\u@\H ${cfg.glyph} [\w]\n\[\e[1m\]└──╸\[\e[0m\]\$ '
      else
        # Local form: Gruvbox neutral blue path + cluster glyph (rarely seen —
        # cluster nodes are headless, this only fires on serial / direct login).
        PS1='\[\e[38;5;67m\]\w\[\e[0m\] ${cfg.glyph} \$ '
      fi
      export PS1
    '';
  };
}
