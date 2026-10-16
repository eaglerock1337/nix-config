# Quickstart: Gibson NixOS Desktop Onboarding

## Prerequisites

- NixOS 25.11 minimal ISO on USB drive
- Physical access to Gibson
- This repo cloned and on the `002-gibson-nixos-onboard` branch

## Development (on Silicon or Gibson)

```bash
# After code changes, validate both hosts (Principle VII: use Makefile targets)
make dry-run HOST=silicon   # regression check — must be unchanged
make dry-run HOST=gibson    # new config check
```

## Installation (on Gibson)

```bash
# 1. Boot NixOS ISO from USB
# 2. Partition 2TB NVMe
gdisk /dev/nvme<X>n1
# Create: 512MB EFI (type EF00), 32GB swap (type 8200), remainder Linux (type 8300)

mkfs.fat -F 32 /dev/nvme<X>n1p1
mkswap /dev/nvme<X>n1p2
mkfs.ext4 /dev/nvme<X>n1p3

mount /dev/nvme<X>n1p3 /mnt
mkdir -p /mnt/boot
mount /dev/nvme<X>n1p1 /mnt/boot
swapon /dev/nvme<X>n1p2

# 3. Generate hardware config
nixos-generate-config --root /mnt

# 4. Copy generated config, discover hardware
cat /mnt/etc/nixos/hardware-configuration.nix  # → hosts/gibson/hardware-configuration.nix
xrandr  # → discover output names for i3-gibson.nix
ip link  # → discover network interface names for hostProfile

# 5. Update repo with real values (UUIDs, output names, interfaces)
# 6. Install
nixos-install --flake /path/to/nix-config#gibson

# 7. Reboot and verify
```

## Post-Install Verification

```bash
nvidia-smi                           # GPU detected
mount | grep -E 'mnt|srv'            # drives mounted
xrandr                               # 3 monitors at correct resolutions
evtest                               # peripheral detection
jstest /dev/input/js0                 # joystick test
fftest /dev/input/event<X>           # G29 force feedback test
```

## Module Directory Structure (post-reorg)

```
modules/
├── nixos/                    # NixOS system modules
│   ├── common.nix            # Shared across all hosts
│   ├── workstation.nix       # Workstation entry point (defines custom.hostProfile options)
│   ├── server.nix            # Server entry point (was cluster/common.nix)
│   ├── k8s.nix               # K8s prerequisites
│   ├── operator.nix          # Operator user module
│   ├── shell/                # Shell config (common.nix, utilities.nix)
│   ├── workstation/          # desktop-ui, gaming, grub, grub/
│   └── server/               # motd, prompt, hlc/
├── home/                     # Home-manager modules
│   ├── base.nix, colors.nix  # Shared
│   ├── workstation.nix       # Workstation entry point (imports i3/common.nix)
│   ├── server.nix            # Server entry point
│   ├── dotfiles/, themes/    # Shared support files (referenced by base.nix)
│   ├── server/               # Future server home modules (.gitkeep)
│   └── workstation/          # polybar, dunst, ui, dev, vscode, layouts/, scripts/
│       └── i3/               # common.nix, laptop.nix, gibson.nix
├── hardware/                 # Hardware modules
│   ├── x1-carbon.nix         # Silicon laptop
│   ├── gibson.nix            # Gibson desktop
│   └── rpi/                  # rpi4.nix, rpi5.nix, rpi-eeprom.nix, sd/
lib/
└── hlc.nix                   # HLC helpers extracted from flake.nix
```
