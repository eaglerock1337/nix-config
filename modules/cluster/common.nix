{ lib, operatorPubkey, ... }: {
  # TODO Phase 6: imports = [ ../shell/utilities.nix ../shell/common.nix ../shell/prompt.nix ../motd/default.nix ../users/operator.nix ]

  networking.domain = lib.mkDefault "marks.dev";
  services.openssh.enable = true;
  users.mutableUsers = false;

  # Operator user; moved to modules/users/operator.nix in Phase 6
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };
}
