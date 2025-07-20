# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    # i3 environment
    i3
    i3status
    feh
    rofi
    rofi-calc
    rofi-systemd
    rofi-top
    rofi-file-browser
    rofi-network-manager
    rofi-power-menu
    picom
    xterm
    xfce.thunar
    dunst
    nnn

    # utilities
    scrot
    flameshot
    gimp3-with-plugins
    rpi-imager
    arandr

    # Multimedia
    vlc
    hexchat
    discord
    bluez
    blueman

    # Utilities
    playerctl
    pamixer        # volume control
    brightnessctl  # brightness (optional)
    i3lock-color   # lock screen
    xss-lock       # lock screen on sleep/suspend
    imagemagick    # screen blur
    alacritty      # terminal

    # GTK & Theming
    gnome-tweaks
    gruvbox-gtk-theme
    gruvbox-plus-icons
    lxappearance
    themix-gui

    # Fonts
    fira    
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  # Enable networking
  networking.networkmanager.enable = true;

  services.xserver = {
    enable = true;
    displayManager = {
      lightdm = {
        enable = true;
        background = ./. + "/../../assets/login.png";
        greeters.enso = {
          enable = true;
          theme = {
            name = "Gruvbox-Dark";
            package = pkgs.gruvbox-gtk-theme;
          };
          extraConfig = ''
            font-name = Fira Sans 24
          '';
        };
      };
      gdm.enable = false;
    };
    desktopManager.gnome.enable = true;
    windowManager.i3.enable = true;
  };

  services.displayManager.defaultSession = "none+i3";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Install firefox
  programs.firefox.enable = true;
}
