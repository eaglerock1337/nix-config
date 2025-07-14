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
    neovim          # Modern Vim
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
    direnv          # Auto-env loading
    git
    gh              # GitHub CLI
    unzip
    zip
    file
    man-db
    tldr            # Simplified man pages
  ];

  fonts.fontconfig.enable = true;
}
