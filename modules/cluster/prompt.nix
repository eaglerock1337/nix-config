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
        Central decoration shown between user@host and cwd in the PS1. Defaults to
        a generic dash; each cluster (HLC, Ecto-1, ...) overrides with its own
        glyph in `modules/cluster/<name>/default.nix`.
      '';
    };
  };

  config = {
    # PS1 set via promptInit so it runs at the correct point in bash
    # initialization. profile.d scripts are sourced before promptInit, so
    # the NixOS default PS1 would overwrite a profile.d-based approach.
    programs.bash.promptInit = ''
      # Cluster PS1 (generated from modules/cluster/prompt.nix)
      # 256-color Gruvbox palette: 109=teal, 214=gold, 142=green, 15=bright white
      PS1='\[\e[38;5;109m\]┌─╸\[\e[38;5;214m\]\u\[\e[38;5;15m\]@\[\e[38;5;214m\]\H\[\e[0m\] ${cfg.glyph} \[\e[38;5;109m\][\[\e[38;5;142m\]\w\[\e[38;5;109m\]]\[\e[0m\]\n\[\e[38;5;109m\]└──╸\[\e[38;5;15m\]\$\[\e[0m\] '
    '';
  };
}
