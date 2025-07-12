{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    feh
    rofi
    picom
    polybar
    nerdFont
    alacritty
    xterm
    firefox
    xchat
    steam
    thunar
    htop
    playerctl
    pamixer        # volume control
    brightnessctl  # brightness (optional)
    i3lock         # lock screen
    alacritty      # terminal
  ];

  fonts.fontconfig.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    fira-code
    droid-sans-mono
  ];
}
