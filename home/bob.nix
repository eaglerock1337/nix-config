# HLC cluster operator (bob) home-manager config.
# Inherits the generic server tier; HLC-specific home bits inline here.

{ pkgs, ... }:

{
  imports = [ ../modules/home/server.nix ];

  home.username = "bob";
  home.homeDirectory = "/home/bob";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
