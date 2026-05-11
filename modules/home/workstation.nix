# Workstation-tier home-manager defaults.
# Consumed by silicon's home/eaglerock.nix; bundles the GUI / desktop
# home-manager modules (i3, polybar, dunst, dev tooling, vscode). Cluster
# nodes MUST NOT import this module — these dependencies belong on the
# workstation only.

{ ... }:

{
  imports = [
    ./base.nix
    ./ui.nix
    ./i3.nix
    ./polybar.nix
    ./dunst.nix
    ./dev.nix
    ./vscode.nix
  ];
}
