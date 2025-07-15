{ config, lib, pkgs, ... }:

let
  themeSource = ./grub; # dir containing theme.txt, png, pf2
  # gruvboxTheme = pkgs.stdenv.mkDerivation {
  #   name = "gruvbox-grub-theme";
  #   # Point src at the folder with theme.txt, background.png, converted-font.pf2
  #   src = ./grub;

  #   # We don’t need a build; just an install phase
  #   phases = [ "installPhase" ];
  #   installPhase = ''
  #     mkdir -p $out
  #     cp -a $src/. $out
  #   '';

  #   # Optional metadata
  #   meta.description = "Gruvbox‐style GRUB theme";
  # };

  # hyperFluentSrc = pkgs.fetchFromGitHub {
  #   owner  = "Coopydood";
  #   repo   = "HyperFluent-GRUB-Theme";
  #   rev    = "main";
  #   sha256 = "16ai3nbscxq7gymadllp4gckaxy7w1vpp022b51zykl0ism1kalp";
  # };

  # hyperFluentTheme = pkgs.stdenv.mkDerivation {
  #   name = "hyperfluent-grub-theme";
  #   src  = hyperFluentSrc;
  #   phases = [ "installPhase" ];
  #   installPhase = ''
  #     mkdir -p $out
  #     cp -r $src/nixos/. $out/
  #   '';
  # };
in {
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = themeSource;
    # splashImage = "${gruvboxTheme}/grub-wallpaper.png";
    # font = "${gruvboxTheme}/FiraCode-Regular.pf2";
    # theme = "${gruvboxTheme}/theme.txt";
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;
}
