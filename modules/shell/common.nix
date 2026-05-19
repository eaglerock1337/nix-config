# Bash baseline: canonical shell + system-wide aliases.
# Consumed via modules/hosts/common.nix; applies to all NixOS hosts.
# Home-manager per-user aliases (modules/home/base.nix) override these.

{ pkgs, ... }:

{
  programs.bash.enable = true;
  users.defaultUserShell = pkgs.bash;

  programs.bash.shellAliases = {
    ll = "ls -la";
    la = "ls -A";
    ".." = "cd ..";
    "..." = "cd ../..";
    k = "kubectl";
  };

  environment.variables.EDITOR = "nvim";
}
