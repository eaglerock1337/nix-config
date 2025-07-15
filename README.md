# nix-config

My collection of Nix config files.

## super quick start

- Install NixOS
- Enable SSH key in GitHub (for now)
- `mkdir ~/git` and `git clone git@github.com:eaglerock1337/nix-config.git ~/git`
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
- Set icons to Gruvbox Plus Icon Pack
- Set font to Fira Sans Regular 14

## things to do

- GRUB theme improvements
- Polybar rework
- Corky setup
- Get TTY sessions working
- Clone repos and start building code environments
- Set up GTK config as home-manager file
- Set up secrets management through a private repo (ssh keys, tokens, etc.)
