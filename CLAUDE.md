# Claude Code Context - nix-config

This is a personal NixOS configuration repository for managing a declarative, reproducible Linux system.

## Project Overview

- **Owner**: Peter Marks (eaglerock)
- **System**: ThinkPad X1 Carbon laptop (hostname: `silicon`)
- **NixOS Version**: 25.11 (stable)
- **Desktop Environment**: i3 window manager
- **Theme**: Gruvbox Dark (consistent across all components)

## Quick Reference

### Build Commands
```bash
# Dry-run first (ALWAYS recommended)
sudo nixos-rebuild dry-run --flake .#silicon

# Apply changes
sudo nixos-rebuild switch --flake .#silicon

# Update all flake inputs
nix flake update
```

### Directory Structure
```
flake.nix           # Entry point - inputs and nixosConfigurations
hosts/silicon/      # Machine-specific config + hardware
modules/hosts/      # System modules (common.nix, desktop-ui.nix, gaming.nix)
modules/home/       # Home-manager modules (i3, polybar, vscode, dev tools)
modules/hardware/   # Hardware-specific modules (x1-carbon.nix)
home/               # Per-user home-manager entry points
assets/             # Wallpapers, images
```

### Key Patterns

1. **Flakes**: Uses Nix flakes for reproducibility. All dependencies locked in `flake.lock`.

2. **Modular design**: Each module focuses on one concern. Import modules in host config or home config as needed.

3. **Home-manager integration**: User environment managed via home-manager, integrated into NixOS config.

4. **Stable + unstable**: Most packages from stable (25.11), specific packages from unstable when needed.

5. **Gruvbox everywhere**: Use `modules/home/colors.nix` for color values to maintain consistency.

## Coding Conventions

- **Indentation**: 2 spaces
- **Comments**: Explain "why" not "what"
- **Module files**: One concern per file
- **Package lists**: Alphabetically sorted when practical
- **Unfree packages**: Explicitly allowlisted, avoid adding new ones without discussion

## Available Agents

- **nixy-boi** (`.claude/agents/nixy-boi.md`): NixOS expert for system management, troubleshooting, and learning. Friendly SRE personality, always dry-runs before changes.

## Safety Notes

- Always dry-run before applying changes
- Be careful with hardware modules (power/thermal settings)
- Boot configuration changes need extra scrutiny
- Test significant changes with `nixos-rebuild build-vm` when feasible
