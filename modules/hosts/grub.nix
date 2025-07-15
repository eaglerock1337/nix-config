{ config, lib, pkgs, ... }:

let
  dir = builtins.getEnv "PWD";
  grubTheme = "${dir}/grub/theme.txt";
in {
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "/dev/nvme0n1";
    theme = builtins.toString grubTheme;
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
