{ config, pkgs, ... }:

{
  home.username = "eaglerock";
  home.homeDirectory = "/home/eaglerock";
  home.stateVersion = "25.05";

  imports = [
    ../modules/home/base.nix
    ../modules/home/ui.nix
    ../modules/home/i3.nix
    ../modules/home/dev.nix
    ../modules/home/vscode.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
