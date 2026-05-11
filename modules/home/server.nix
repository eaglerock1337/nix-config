# Server-tier home-manager defaults.
# Consumed by cluster operator home files (home/bob.nix for HLC; future
# home/<slimer>.nix for Ecto-1). Layered on top of base.nix.

{ pkgs, ... }:

{
  imports = [ ./base.nix ];

  programs.tmux = {
    enable = true;
    shortcut = "a";           # Ctrl-a prefix (silicon convention)
    historyLimit = 50000;
    clock24 = true;
  };

  home.sessionVariables = {
    KUBECONFIG = "$HOME/.kube/config";
  };
}
