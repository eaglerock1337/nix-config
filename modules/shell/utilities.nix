# Sysadmin toolbox (FR-015).
# Baseline package set for all NixOS hosts — workstations and cluster nodes.
# Every entry carries an inline comment describing its purpose.

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Shell & File Utilities ---
    bash            # The GNU Bourne Again SHell
    bat             # Better cat with syntax highlighting
    eza             # Better ls (exa successor)
    fd              # Fast alternative to find
    ripgrep         # Fast grep (provides `rg`)
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
    killall         # Kill processes by name

    # --- Editors & Viewers ---
    micro           # Friendly terminal editor
    neovim          # Default editor (configured in modules/home/base.nix)
    vim             # Classic modal editor (fallback when neovim unavailable)
    less            # Pager
    glow            # Markdown previewer

    # --- Process & System Tools ---
    htop            # System monitor
    btop            # Fancy resource monitor
    lsof            # List open files
    strace          # Syscall tracing
    iotop           # I/O monitor
    dool            # Versatile resource monitor (dstat successor)
    ncdu            # TUI disk usage explorer
    efibootmgr      # EFI boot manager
    caffeine-ng     # Prevent sleep

    # --- Storage & Disk ---
    mdadm           # Linux software RAID management (cluster USB RAID)
    parted          # Partition editor
    pciutils        # lspci and friends
    usbutils        # lsusb and friends

    # --- Networking ---
    curl            # HTTP/transfer client
    wget            # HTTP downloader
    httpie          # Human-friendly curl
    fping           # Parallel ping
    dig             # DNS lookup (BIND utilities)
    iperf3          # Network throughput test
    mtr             # Traceroute + ping
    nmap            # Network scanner
    socat           # Multipurpose socket relay
    rsync           # File sync over SSH
    openssh         # SSH client/server
    iproute2        # ip/ss/tc — modern net tools
    tcpdump         # Packet capture

    # --- Security & Secrets ---
    gnupg           # GnuPG (PGP encryption + signing)
    gnutls          # TLS library + CLI utilities
    age             # Modern file encryption
    pinentry-curses # Terminal pinentry for GnuPG
    pinentry-gnome3 # GNOME pinentry for GnuPG (workstation)
    pass            # Standard Unix password manager

    # --- Productivity / Enhancements ---
    tmux            # Terminal multiplexer
    entr            # Run commands on file changes
    delta           # Beautiful diff viewer (git-friendly)
    unzip           # ZIP archive extractor
    zip             # ZIP archive creator
    file            # File type identification
    man-db          # Manual page reader
    tldr            # Simplified man pages
    neofetch        # System info banner

    # --- Containerization & Kubernetes ---
    kubectl         # Kubernetes CLI
    k9s             # Kubernetes TUI
    kubernetes-helm # Helm — Kubernetes package manager
    minikube        # Local single-node k8s (workstation dev)
    kind            # Kubernetes-in-Docker (workstation dev)

    # --- Nix Tools ---
    nh              # Nix helper with smarter GC (`nh clean all --keep 3`)
  ];
}
