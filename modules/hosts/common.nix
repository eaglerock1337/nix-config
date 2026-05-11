# Top-level catchall consumed by every NixOS host (workstation + cluster).
# Holds only truly universal content: nix settings, time, locale, openssh,
# allowUnfree, binfmt. Workstation-specific configuration (PS1, docker, helper
# functions) lives in modules/hosts/workstation.nix and is imported only by
# workstation hosts.

{ pkgs, ... }:

{
  imports = [
    ../shell/utilities.nix
    ../shell/common.nix
    ../users/operator.nix
  ];

  # Nix settings
  nix.settings = {
    experimental-features = "nix-command flakes";
    # Automatically deduplicate files in the store
    auto-optimise-store = true;
    # Disk-pressure based garbage collection fallback
    # Triggers GC during builds when free space drops below 1GB
    min-free = "${toString (1 * 1024 * 1024 * 1024)}";
    # Stops GC when free space reaches 5GB
    max-free = "${toString (5 * 1024 * 1024 * 1024)}";
    # nvmd/nixos-raspberrypi binary cache — prebuilt aarch64 kernels/firmware
    substituters = [
      "https://cache.nixos.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  # Time zone
  time.timeZone = "America/New_York";

  # Internationalisation
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # OpenSSH daemon — single source of truth across the fleet
  services.openssh.enable = true;

  # `nr` rebuilds the local host's NixOS config; `ndr` dry-runs it. Both shell
  # out to `nixos-rebuild` against ~/git/nix-config, keyed off `hostname -s` so
  # the same definition works on any workstation or cluster node.
  programs.bash.interactiveShellInit = ''
    nr() {
      sudo nixos-rebuild switch --flake ~/git/nix-config#"$(hostname -s)" "$@";
    }
    ndr() {
      sudo nixos-rebuild dry-run --flake ~/git/nix-config#"$(hostname -s)" "$@";
    }
  '';
}
