{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";  # Set default editor
    VISUAL = "nvim";  # Set default visual editor
    PAGER = "less";   # Set default pager
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

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
