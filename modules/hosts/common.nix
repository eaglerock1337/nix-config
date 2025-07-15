# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [ ];

  nix.settings.experimental-features = "nix-command flakes";

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
    extraGroups = [ "networkmanager" "wheel" ];
  };

  programs.bash = {
    interactiveShellInit = ''
      nr() {
        sudo nixos-rebuild switch --flake ~/git/nix-config#"$(hostname -s)" "$@";
      }
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
    du-dust         # Better du
    duf             # Disk usage/free visualizer
    tree            # Directory tree view
    zoxide          # Smarter cd
    jq              # JSON processor
    yq              # YAML processor
    sd              # Intuitive sed replacement
    git             # Version control

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
    neofetch

    # --- Containerization ---
    docker_28
    kubectl
    k9s
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
