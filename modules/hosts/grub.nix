{ config, lib, pkgs, ... }:

let
  grubTheme = "./grub/theme.txt";
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
