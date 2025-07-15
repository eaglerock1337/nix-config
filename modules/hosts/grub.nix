{ config, lib, pkgs, ... }:

let
  # dir = builtins.toString ./.;
  # grubTheme = "${dir}/grub/theme.txt";
  gruvboxTheme = pkgs.runCommand "grub-theme" {} ''
    mkdir -p $out
    cp -r ${grubThemePath}/* $out/
  '';
in {
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = ${gruvboxTheme}/theme.txt;
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
