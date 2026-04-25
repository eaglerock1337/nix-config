# HLC-specific MOTD configuration.
# Sets the ASCII art banner and Bob Ross quote for Happy Little Cloud nodes.
# This module is imported alongside modules/motd/default.nix which provides
# the options and writes /etc/motd.
{ ... }:

{
  cluster.motd = {
    enable = true;
    clusterName = "Happy Little Cloud";
    asciiArt = ''
       _   _ _     ____
      | | | | |   / ___|
      | |_| | |  | |
      |  _  | |__| |___
      |_| |_|_____\____|

      Happy Little Cloud — NixOS k3s Cluster
    '';
    tagline = "We don't make mistakes, just happy little accidents.";
    attribution = "~ Bob Ross";
  };
}
