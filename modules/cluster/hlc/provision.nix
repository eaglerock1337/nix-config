# Provision-minimal cluster module
# Installed by nixos-anywhere stage2 to get a bootable, SSH-reachable system
# with a small closure. The full config is pushed later via `make update-node`
# (provision-stage3).
#
# Imports only what's needed for SSH + sudo + nix + RAID boot.
# Does NOT import: home-manager, utilities.nix, shell/common.nix, motd.nix,
# prompt.nix, hosts.nix (/etc/hosts), or git-clone activation.

{ config, lib, pkgs, operatorPubkeys, ... }: {
  imports = [
    ./options.nix
    ./raid-fallback.nix
    ../../users/operator.nix
  ];

  networking.domain = "marks.dev";

  users.mutableUsers = false;

  # HLC cluster operator (provision-minimal: account only, no home-manager)
  system.operator = {
    name = "bob";
    pubkeys = operatorPubkeys;
    description = "HLC cluster operator";
  };

  # Allow bob to receive nix store paths via `nix copy` from gibson
  nix.settings.trusted-users = [ "root" "bob" ];

  users.users.root.openssh.authorizedKeys.keys = operatorPubkeys;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # W-002: passwordless wheel during cluster transition
  security.sudo.wheelNeedsPassword = false;

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    download-buffer-size = 256 * 1024 * 1024;
    min-free = "${toString (1 * 1024 * 1024 * 1024)}";
    max-free = "${toString (5 * 1024 * 1024 * 1024)}";
    substituters = [
      "https://cache.nixos.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;
}
