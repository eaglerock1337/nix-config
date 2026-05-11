{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home = {
    sessionVariables = {
      EDITOR = "nvim";  # Set default editor
      VISUAL = "nvim";  # Set default visual editor
      PAGER = "less";   # Set default pager
    };

    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "eza -l --group-directories-first";          # eza for better ls
      la = "eza -la --group-directories-first";         # eza listing including dotfiles
      grep = "rg";                                      # ripgrep as default grep
      gpnr = "cd ~/git/nix-config && git pull && nr";   # Pull config and rebuild local host
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    extraConfig = ''
      syntax enable
      set termguicolors
      set background=dark
      colorscheme gruvbox
    '';

    plugins = with pkgs.vimPlugins; [
      gruvbox
      vim-airline
      vim-airline-themes
      lightline-vim
      nerdtree
      fzf-vim
    ];
  };

  home.file = {
    ".vimrc".source = ./dotfiles/vimrc;
    ".config/nvim/colors/gruvbox.vim".source = ./themes/vim/gruvbox.vim;
    ".config/nvim/autoload/airline/themes/gruvbox_airline.vim".source = ./themes/airline/gruvbox.vim;
    ".config/nvim/autoload/lightline/colorscheme/gruvbox_lightline.vim".source = ./themes/lightline/gruvbox.vim;
  };

  fonts.fontconfig.enable = true;
}
