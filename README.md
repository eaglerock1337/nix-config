# nix-config

My collection of Nix config files.

## quickstart

- Install NixOS
- Enable SSH key in GitHub (for now)
- `mkdir ~/git` and `git clone git@github.com:eaglerock1337/nix-config.git ~/git`
- Add new directory for host in `hosts/` and add `configuration.nix`
- Install modules as needed
- Add hardware-configuration.nix from installation and install
- Add to `flake.nix` with home-manager configuration for needed users
- Finally, simlink the nix-config repo and apply to the system:

```bash
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s /home/eaglerock/git/nix-config /etc/nixos
sudo nixos-rebuild switch --flake ~/git/nix-config#gibson  # substitute hostname
```

### manual edits for now

#### lxappearance

- Set theme to Gruvbox-Dark
- Set icons to Gruvbox Plus Icon Pack
- Set font to Fira Sans Regular 12

## things to do

- GRUB theme improvements
- Polybar embellishments - click actions + fix battery display when not charging on AC
- Corky setup - nice fancy desktop-based system metrics
- Get TTY sessions working
- Clone repos and start building code environments
- Get more vscode improvements in place (important plugins, desired config settings, etc.)
- Determine direnv-based code solution for my repos
- Determine baseline preinstalled languages as well (Python, Ruby, etc.)
- Set up GTK config as home-manager file

### other goals

- Enable disk encryption (should've done this before)
- Set up secrets management through a private repo (ssh keys, tokens, etc.)
- Modularize all setups that will differ between laptop and desktop setups (i3 configs, etc.)
