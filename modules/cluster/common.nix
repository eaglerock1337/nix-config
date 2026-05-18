{ config, lib, pkgs, operatorPubkeys, ... }: {
  imports = [
    ../hosts/common.nix
    ./motd.nix
    ./prompt.nix
    ../k8s/prereqs.nix
  ];

  networking.domain = lib.mkDefault "marks.dev";
  users.mutableUsers = false;

  # Cluster security policy. Workstations explicitly opt out by NOT importing
  # this module — silicon keeps password sudo + password SSH at NixOS defaults.

  # W-002: passwordless wheel during cluster transition; remove once sops-nix
  # secrets management lands (feature 002).
  security.sudo.wheelNeedsPassword = false;

  # W-003 closed: key-only SSH enforced post-provisioning on cluster nodes.
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

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
          { name = "nix-config"; url = "https://github.com/eaglerock1337/nix-config.git"; }
          # { name = "happy-little-cloud"; url = "https://github.com/eaglerock1337/happy-little-cloud.git"; }
        ];
        cloneCommands = lib.concatMapStringsSep "\n" (repo: ''
          if [ ! -d "${operatorHome}/git/${repo.name}" ]; then
            GIT_TERMINAL_PROMPT=0 ${pkgs.git}/bin/git clone ${repo.url} ${operatorHome}/git/${repo.name} || true
            if [ -d "${operatorHome}/git/${repo.name}" ]; then
              chown -R ${operatorName}:users ${operatorHome}/git/${repo.name}
            fi
          fi
        '') repos;
      in ''
        mkdir -p ${operatorHome}/git
        chown ${operatorName}:users ${operatorHome}/git
        ${cloneCommands}
      ''
    );
}
