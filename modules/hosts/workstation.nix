# Workstation-tier system module.
# Layers silicon-flavored bash environment, helper functions, and desktop
# infrastructure on top of the universal catchall. Cluster nodes MUST NOT
# import this module.

{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Cross-compile aarch64 via qemu when cache misses occur (cluster image builds).
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Workstation-only convenience functions: `nr` rebuilds the local host's
  # NixOS config, `ndr` dry-runs it. Both shell out to `nixos-rebuild` against
  # ~/git/nix-config, keyed off `hostname -s` so the same definition works on
  # any future workstation.
  programs.bash = {
    interactiveShellInit = ''
      nr() {
        sudo nixos-rebuild switch --flake ~/git/nix-config#"$(hostname -s)" "$@";
      }
      ndr() {
        sudo nixos-rebuild dry-run --flake ~/git/nix-config#"$(hostname -s)" "$@";
      }
    '';
    promptInit = ''
      # Gruvbox color palette
      RESET='\[\e[0m\]'
      BOLD='\[\e[1m\]'

      # Gruvbox ANSI colors
      FG_BLUE='\[\e[38;5;67m\]'      # neutral blue (#458588)
      FG_YELLOW='\[\e[38;5;136m\]'   # neutral yellow (#d79921)
      FG_RED='\[\e[38;5;124m\]'      # neutral red (#cc241d)
      FG_AQUA='\[\e[38;5;108m\]'     # neutral aqua (#689d6a)
      FG_PURPLE='\[\e[38;5;132m\]'   # neutral purple (#b16286)
      FG_GRAY='\[\e[38;5;243m\]'     # light4 (#a89984)
      FG_GREEN='\[\e[38;5;100m\]'
      BG_NONE='\'

      # Unicode symbols
      SLASH=$''  #
      PROMPT="$FG_RED$SLASH$FG_YELLOW$SLASH$FG_GREEN$SLASH$FG_AQUA$SLASH$RESET "

      # Get user and host
      USER_HOST="$FG_GRAY\u@\h$RESET"

      # Determine session type
      if [[ "$EUID" -eq 0 ]]; then
          PATH_COLOR="$FG_RED"
      elif [[ -n "$SSH_CONNECTION" ]]; then
          PATH_COLOR="$FG_PURPLE"
      else
          PATH_COLOR="$FG_BLUE"
      fi

      # Set window title
      # TODO: fix CWD to properly substitute $HOME with ~
      PROMPT_COMMAND='CWD=$\{$PWD/#$HOME/~}; printf "\033]0;%s@%s: %s\007" "$USER" "$HOSTNAME" "$PWD"'

      # Show user@host only for SSH sessions
      if [[ -n "$SSH_CONNECTION" ]]; then
          export PS1="$USER_HOST $PATH_COLOR \w $RESET$PROMPT"
      else
          export PS1="$PATH_COLOR \w $RESET$PROMPT"
      fi
    '';
  };

  virtualisation.docker.enable = true;
}
