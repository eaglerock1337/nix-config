# Workstation-tier home-manager defaults
# Consumed by silicon's home/eaglerock.nix; bundles the GUI / desktop
# home-manager modules (i3, polybar, dunst, dev tooling, vscode).

{ ... }:

{
  imports = [
    ./base.nix
    ./workstation/ui.nix
    ./polybar.nix
    ./workstation/dunst.nix
    ./workstation/dev.nix
    ./workstation/vscode.nix
  ];
}
