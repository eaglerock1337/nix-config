{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # --- Shell & File Utilities ---
    bat             # Better cat with syntax highlighting
    eza             # Better ls
    fd              # Fast alternative to find
    ripgrep         # Fast grep (used by many fuzzy finders)
    fzf             # Fuzzy finder
    du-dust         # Better du
    duf             # Disk usage/free visualizer
    tree            # Directory tree view
    zoxide          # Smarter cd
    jq              # JSON processor
    yq              # YAML processor
    sd              # Intuitive sed replacement

    # --- Editors & Viewers ---
    micro           # Friendly terminal editor
    less            # Pager
    glow            # Markdown previewer

    # --- Process & System Tools ---
    htop            # System monitor
    btop            # Fancy resource monitor
    lsof            # List open files
    strace          # Syscall tracing
    iotop           # I/O monitor
    dool            # Versatile resource monitor
    ncdu            # TUI disk usage explorer

    # --- Networking ---
    curl
    wget
    httpie          # Human-friendly curl
    dig
    iperf3
    mtr             # Traceroute+ping
    nmap
    socat
    rsync
    openssh

    # --- Security & Secrets ---
    gnupg
    gnutls
    age
    pinentry
    pass            # Standard Unix password manager

    # --- Productivity / Enhancements ---
    tmux
    entr            # Run commands on file changes
    delta           # Beautiful diff viewer
    unzip
    zip
    file
    man-db
    tldr            # Simplified man pages
  ];

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
    ".config/nvim/colors/gruvbox.vim".source = ./themes/vim/gruvbox.vim;
    ".config/nvim/init.vim".source = ./themes/vim/init.vim;
    ".config/nvim/autoload/airline/themes/gruvbox_airline.vim".source = ./themes/airline/gruvbox.vim;
    ".config/nvim/autoload/lightline/colorscheme/gruvbox_lightline.vim".source = ./themes/lightline/gruvbox.vim;
  };

  fonts.fontconfig.enable = true;
}
