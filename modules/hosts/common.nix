# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [ ];

  # Nix settings
  nix.settings = {
    experimental-features = "nix-command flakes";
    # Automatically deduplicate files in the store
    auto-optimise-store = true;
    # Disk-pressure based garbage collection fallback
    # Triggers GC during builds when free space drops below 1GB
    min-free = "${toString (1 * 1024 * 1024 * 1024)}";
    # Stops GC when free space reaches 5GB
    max-free = "${toString (5 * 1024 * 1024 * 1024)}";
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.eaglerock = {
    isNormalUser = true;
    description = "Peter Marks";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  programs.bash = {
    interactiveShellInit = ''
      nr() {
        sudo nixos-rebuild switch --flake ~/git/nix-config#"$(hostname -s)" "$@";
      }
      ndr() {
        sudo nixos-rebuild dry-run --flake ~/git/nix-config#"$(hostname -s)" "$@";
      }
    '';
    promptInit = ''
      # Gruvbox color palette
      RESET='\[\e[0m\]'
      BOLD='\[\e[1m\]'

      # Gruvbox ANSI colors
      FG_BLUE='\[\e[38;5;67m\]'      # neutral blue (#458588)
      FG_YELLOW='\[\e[38;5;136m\]'   # neutral yellow (#d79921)
      FG_RED='\[\e[38;5;124m\]'      # neutral red (#cc241d)
      FG_AQUA='\[\e[38;5;108m\]'     # neutral aqua (#689d6a)
      FG_PURPLE='\[\e[38;5;132m\]'   # neutral purple (#b16286)
      FG_GRAY='\[\e[38;5;243m\]'     # light4 (#a89984)
      FG_GREEN='\[\e[38;5;100m\]'
      BG_NONE='\'

      # Unicode symbols
      SLASH=$'\ue216'  # 
      PROMPT="$FG_RED$SLASH$FG_YELLOW$SLASH$FG_GREEN$SLASH$FG_AQUA$SLASH$RESET "

      # Get user and host
      USER_HOST="$FG_GRAY\u@\h$RESET"

      # Determine session type
      if [[ "$EUID" -eq 0 ]]; then
          PATH_COLOR="$FG_RED"
      elif [[ -n "$SSH_CONNECTION" ]]; then
          PATH_COLOR="$FG_PURPLE"
      else
          PATH_COLOR="$FG_BLUE"
      fi

      # Set window title
      # TODO: fix CWD to properly substitute $HOME with ~
      PROMPT_COMMAND='CWD=$\{$PWD/#$HOME/~}; printf "\033]0;%s@%s: %s\007" "$USER" "$HOSTNAME" "$PWD"'

      # Show user@host only for SSH sessions
      if [[ -n "$SSH_CONNECTION" ]]; then
          export PS1="$USER_HOST $PATH_COLOR \w $RESET$PROMPT"
      else
          export PS1="$PATH_COLOR \w $RESET$PROMPT"
      fi
    '';
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # --- Shell & File Utilities ---
    bash            # The GNU Bourne Again SHell
    bat             # Better cat with syntax highlighting
    eza             # Better ls
    fd              # Fast alternative to find
    ripgrep         # Fast grep (used by many fuzzy finders)
    fzf             # Fuzzy finder
    dust            # Better du
    duf             # Disk usage/free visualizer
    tree            # Directory tree view
    zoxide          # Smarter cd
    jq              # JSON processor
    yq              # YAML processor
    sd              # Intuitive sed replacement
    git             # Version control
    busybox         # Compact utility shell
    killall         # Kill utility

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
    efibootmgr      # EFI boot manager
    caffeine-ng     # Prevent sleep

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
    pinentry-curses
    pinentry-gnome3
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
    neofetch

    # --- Containerization ---
    kubectl
    k9s
    kubernetes-helm
    minikube
    kind

    # --- Nix Tools ---
    nh              # Nix helper with smarter GC (nh clean all --keep 3)
  ];

  virtualisation.docker.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
