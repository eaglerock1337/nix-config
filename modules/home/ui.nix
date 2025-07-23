{ config, pkgs, ... }:

let
  nerdFont = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
in {
  # TODO: Enable GTK theming
  # gtk = {
  #   enable = true;

  #   theme = {
  #     name = "Gruvbox-dark";
  #     package = pkgs.gruvbox-gtk-theme;
  #   };

  #   font = {
  #     name = "Fira Sans 16";
  #   };

  #   iconTheme = {
  #     name = "Papirus-Dark";
  #     package = pkgs.papirus-icon-theme;
  #   };
  # };

  # ROFI Config
  programs.rofi = {
    enable = true;
    theme = "gruvbox-dark";
    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      font = "FiraCode Nerd Font 16";
    };
  };

  services.picom = {
    enable = true;
    fade = true;
    shadow = true;
    vSync = true;
  };

  programs.alacritty = {
    enable = true;
    theme = "gruvbox_dark";
    settings = {
      font = {
        normal.family = "FiraCode Nerd Font";
        size = 11;
      };
      window = {
        opacity = 0.8;
        dynamic_title = true;
      };
    };
  };

  home.file = {
    ".local/bin/lock" = {
      source = ./scripts/lock;
      executable = true;
    };
  };

  systemd.user.services.gnome-keyring-daemon = {
    Unit.Description = "GNOME Keyring";
    Service.ExecStart = "${pkgs.gnome.gnome-keyring}/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg";
    Install.WantedBy = [ "default.target" ];
  };
}
