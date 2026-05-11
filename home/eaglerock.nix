{ pkgs, ... }:

{
  imports = [ ../modules/home/workstation.nix ];

  home.username = "eaglerock";
  home.homeDirectory = "/home/eaglerock";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
