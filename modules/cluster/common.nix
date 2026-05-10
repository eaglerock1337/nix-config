{ lib, pkgs, operatorPubkeys, ... }: {
  # TODO Phase 6: imports = [ ../shell/utilities.nix ../shell/common.nix ../shell/prompt.nix ../motd/default.nix ../users/operator.nix ]

  networking.domain = lib.mkDefault "marks.dev";
  services.openssh.enable = true;
  users.mutableUsers = false;

  # W-002: passwordless wheel until sops-nix secrets management lands (Phase 6+)
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
  ];

  # Operator user; moved to modules/users/operator.nix in Phase 6
  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = operatorPubkeys;
  };

  # Clone operator repos into ~bob/git on activation
  # Add entries here to extend; activation skips repos that already exist
  system.activationScripts.cloneOperatorRepos = let
    bobHome = "/home/bob";
    repos = [
      { name = "nix-config"; url = "https://github.com/eaglerock/nix-config.git"; }
      # { name = "happy-little-cloud"; url = "https://github.com/eaglerock/happy-little-cloud.git"; }
    ];
    cloneCommands = lib.concatMapStringsSep "\n" (repo: ''
      if [ ! -d "${bobHome}/git/${repo.name}" ]; then
        ${pkgs.git}/bin/git clone ${repo.url} ${bobHome}/git/${repo.name}
        chown -R bob:users ${bobHome}/git/${repo.name}
      fi
    '') repos;
  in ''
    mkdir -p ${bobHome}/git
    chown bob:users ${bobHome}/git
    ${cloneCommands}
  '';
}
