{ config, lib, pkgs, operatorPubkeys, ... }: {
  imports = [
    ../hosts/common.nix
    ./motd.nix
    ./prompt.nix
    # TODO Phase 7: import ../k8s/prereqs.nix
  ];

  networking.domain = lib.mkDefault "marks.dev";
  users.mutableUsers = false;

  # W-010: root SSH for nixos-anywhere provisioning and recovery operations
  users.users.root.openssh.authorizedKeys.keys = operatorPubkeys;

  # Clone operator repos into the operator's ~/git on activation.
  # Add entries here to extend; activation skips repos that already exist.
  system.activationScripts.cloneOperatorRepos =
    lib.mkIf (config.system.operator.name != null) (
      let
        operatorName = config.system.operator.name;
        operatorHome = "/home/${operatorName}";
        repos = [
          { name = "nix-config"; url = "https://github.com/eaglerock/nix-config.git"; }
          # { name = "happy-little-cloud"; url = "https://github.com/eaglerock/happy-little-cloud.git"; }
        ];
        cloneCommands = lib.concatMapStringsSep "\n" (repo: ''
          if [ ! -d "${operatorHome}/git/${repo.name}" ]; then
            ${pkgs.git}/bin/git clone ${repo.url} ${operatorHome}/git/${repo.name}
            chown -R ${operatorName}:users ${operatorHome}/git/${repo.name}
          fi
        '') repos;
      in ''
        mkdir -p ${operatorHome}/git
        chown ${operatorName}:users ${operatorHome}/git
        ${cloneCommands}
      ''
    );
}
