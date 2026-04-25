# Curated sysadmin CLI utilities shared across all managed systems.
# Provides a 'syshelp' command that prints a colorized, categorized tool reference.
# Keep this list lean — cluster/desktop-specific tools go in their own modules.
{ pkgs, ... }:

let
  syshelp = pkgs.writeShellScriptBin "syshelp" ''
    bold='\033[1m'
    cyan='\033[36m'
    reset='\033[0m'

    section() { printf "\n''${bold}''${cyan}%s''${reset}\n" "$1"; }
    entry()   { printf "  %-18s %s\n" "$1" "$2"; }

    printf "''${bold}Sysadmin Tool Reference''${reset} — run 'syshelp' to see this\n"

    section "Network"
    entry "curl"      "HTTP client, download files, test endpoints"
    entry "dnsutils"  "dig, nslookup — DNS lookups and debugging"
    entry "ethtool"   "Query and configure network interfaces"
    entry "mtr"       "Traceroute + ping in one: real-time path analysis"
    entry "nmap"      "Port scanner and network exploration"
    entry "tcpdump"   "Capture and inspect network traffic"
    entry "wget"      "HTTP/FTP download, recursive site mirroring"

    section "Storage"
    entry "fd"        "Fast alternative to find with friendlier syntax"
    entry "iotop"     "Per-process disk I/O monitor (needs root)"
    entry "ncdu"      "Interactive disk usage analyser"
    entry "tree"      "Directory tree visualiser"

    section "Process"
    entry "htop"      "Interactive process monitor with CPU/mem graphs"
    entry "lsof"      "List open files and network sockets by process"

    section "Search"
    entry "fd"        "Find files by name/pattern quickly"
    entry "ripgrep"   "rg: blazing-fast recursive grep"

    section "Data"
    entry "file"      "Identify file type by content (magic bytes)"
    entry "jq"        "Parse, filter, and format JSON"

    section "Dev / System"
    entry "git"       "Version control"
    entry "pciutils"  "lspci — list PCI devices"
    entry "tmux"      "Terminal multiplexer: persistent sessions over SSH"
    entry "usbutils"  "lsusb — list USB devices"

    printf "\n"
  '';
in {
  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    ethtool
    fd
    file
    git
    htop
    iotop
    jq
    lsof
    mtr
    ncdu
    nmap
    pciutils
    ripgrep
    syshelp
    tcpdump
    tmux
    tree
    usbutils
    wget
  ];
}
