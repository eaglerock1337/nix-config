# Claude Code Context - nix-config

Personal NixOS config repo. Declarative, reproducible Linux system.

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

1. **Flakes**: Nix flakes for reproducibility. All deps locked in `flake.lock`.

2. **Modular design**: One concern per module. Import in host or home config as needed.

3. **Home-manager integration**: User env via home-manager, integrated into NixOS config.

4. **Stable + unstable**: Most packages from stable (25.11), specific packages from unstable when needed.

5. **Gruvbox everywhere**: Use `modules/home/colors.nix` for color values.

## Coding Conventions

- **Indentation**: 2 spaces
- **Comments**: Explain "why" not "what"
- **Module files**: One concern per file
- **Package lists**: Alphabetically sorted when practical
- **Unfree packages**: Explicit allowlist. No new ones without discussion.

## Available Agents

- **nixy-boi** (`.claude/agents/nixy-boi.md`): NixOS expert for system mgmt, troubleshooting, learning. Friendly SRE, always dry-runs before changes.

## Safety Notes

- Always dry-run before applying
- Hardware modules (power/thermal) — careful
- Boot config changes need extra scrutiny
- Test big changes with `nixos-rebuild build-vm` when feasible

## Approach

- Think before acting. Read files before writing code.
- Concise output, thorough reasoning.
- Prefer edit over full rewrite.
- No re-read unless file may have changed.
- Test before declaring done.
- No sycophantic openers or closing fluff.
- Simple, direct solutions.
- User instructions override this file.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at `specs/002-gibson-nixos-onboard/plan.md`

Key design decisions for active feature (002-gibson-nixos-onboard):
- **Copy-first, dedup-later**: Phase 2 moves files + creates independent copies for Gibson; Phase 7 deduplicates into common.nix + host variants
- **Silicon immutability**: `make dry-run HOST=silicon` MUST produce identical store path after every Phase 2 commit; ~10 operator visual checkpoints
- **RPi/cluster immutability**: content-unchanged moves only (FR-027)
- Polybar parameterization (Phase 7): NixOS options (`custom.hostProfile`) + `osConfig`, NOT `extraSpecialArgs`
- i3 Phase 2: independent `laptop.nix` (Silicon rename) + `gibson.nix` (copy). Phase 7: extract `common.nix`, reduce to deltas
- HLC helpers extracted to `lib/hlc.nix`; flake.nix stays pure composition
- Single shared `home/eaglerock.nix` for all workstations
- Module reorg: `modules/hosts/` → `modules/nixos/`, `modules/cluster/` → `modules/nixos/server/`
- NVIDIA driver: `nvidiaPackages.stable` default, commented `.latest` alternative
- Multi-monitor failure: graceful xrandr failure, no autorandr
- Agents MUST NOT run raw nix commands (Principle VII) — use Makefile targets
<!-- SPECKIT END -->
