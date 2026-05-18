# Sysadmin Tool Reference

> **Status**: Reference documentation only. The `syshelp` command does not yet
> exist — see [W-017](../specs/WORKAROUNDS.md#w-017-cluster-operations-managed-via-makefile-no-dedicated-cli-tool)
> for the planned Go CLI utility that will surface this as `hlc syshelp`.

Curated CLI utilities available on all managed systems (HLC cluster nodes, desktop).

## Network

| Tool | Description |
|------|-------------|
| `curl` | HTTP client, download files, test endpoints |
| `dnsutils` | `dig`, `nslookup` — DNS lookups and debugging |
| `ethtool` | Query and configure network interfaces |
| `mtr` | Traceroute + ping combined: real-time path analysis |
| `nmap` | Port scanner and network exploration |
| `tcpdump` | Capture and inspect network traffic |
| `wget` | HTTP/FTP download, recursive site mirroring |

## Storage

| Tool | Description |
|------|-------------|
| `fd` | Fast alternative to `find` with friendlier syntax |
| `iotop` | Per-process disk I/O monitor (requires root) |
| `ncdu` | Interactive disk usage analyser |
| `tree` | Directory tree visualiser |

## Process

| Tool | Description |
|------|-------------|
| `htop` | Interactive process monitor with CPU/memory graphs |
| `lsof` | List open files and network sockets by process |

## Search

| Tool | Description |
|------|-------------|
| `fd` | Find files by name or pattern quickly |
| `ripgrep` (`rg`) | Blazing-fast recursive grep |

## Data

| Tool | Description |
|------|-------------|
| `file` | Identify file type by content (magic bytes) |
| `jq` | Parse, filter, and format JSON |

## Dev / System

| Tool | Description |
|------|-------------|
| `git` | Version control |
| `pciutils` (`lspci`) | List PCI devices |
| `tmux` | Terminal multiplexer: persistent sessions over SSH |
| `usbutils` (`lsusb`) | List USB devices |

## Adding Tools

Add packages to `environment.systemPackages` in `modules/shell/utilities.nix`
and a matching entry to the `syshelp` script in the same file. Keep this list
lean — cluster-specific tools (kubectl, k9s) go in a cluster module; desktop
tools go in a desktop module.
