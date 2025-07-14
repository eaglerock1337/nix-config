# nix-config

My collection of Nix config files.

## super quick start

- Install NixOS
- Add new directory for host in `hosts/` and add `configuration.nix`
- Install modules as needed
- Add hardware-configuration.nix from installation and install
- Add to `flake.nix` with home-manager configuration for needed users

```bash
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s /home/eaglerock/git/nix-config /etc/nixos
sudo nixos-rebuild switch --flake ~/git/nix-config#gibson  # substitute hostname
```

### manual edits for now

#### lxappearance

- Set theme to Gruvbox-Dark
- Set font to Fira Sans Regular 20

## things to do

- GRUB theme
- Choose desktop manager (lightdm?)
- Login screen rework
- Polybar rework
- Corky setup
- Get TTY sessions working
- Clone repos and start building code environments
