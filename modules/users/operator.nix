# Parameterized operator user module.
# Each system class sets its own username (bob/eaglerock/slimer) and SSH keys.
# Using a module option rather than a hardcoded user keeps host configs thin
# and makes the user identity explicit at the call site.
{ config, lib, ... }:

let
  cfg = config.users.operator;
in {
  options.users.operator = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Login name for the primary operator user on this system.";
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Authorized SSH public keys for the operator user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "wheel" ];
      description = "Additional groups for the operator user.";
    };
  };

  config = {
    users.users.${cfg.username} = {
      isNormalUser = true;
      extraGroups = cfg.extraGroups;
      openssh.authorizedKeys.keys = cfg.sshKeys;
    };

    # Passwordless sudo for wheel — nodes are SSH-key-only anyway
    security.sudo.wheelNeedsPassword = false;

    # SSH hardening: prevent hung sessions from cascading and exhausting
    # MaxSessions/MaxStartups slots. Without ClientAlive, a stuck shell
    # holds its slot indefinitely; a few hung sessions block all new logins.
    services.openssh.settings = {
      ClientAliveInterval = 30;
      ClientAliveCountMax = 3;
      LoginGraceTime = 20;
      MaxSessions = 20;
      MaxStartups = "30:30:60";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      UseDns = false;
    };
  };
}
