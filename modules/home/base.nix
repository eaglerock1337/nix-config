{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    feh
    rofi
    picom
    polybar
    alacritty
    xterm
    firefox
    xchat
    steam
    thunar
    htop
    playerctl
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    pamixer        # volume control
    brightnessctl  # brightness (optional)
    i3lock         # lock screen
    alacritty      # terminal
  ];

  fonts.fontconfig.enable = true;
}
