{ operatorPubkey, lib, ... }:

{
  imports = [ ./recovery-utils.nix ];

  networking.hostName = lib.mkDefault "hlc-sd-bootstrap";
  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # pam_systemd creates/destroys D-Bus user sessions on every SSH connect;
  # teardown after non-PTY sessions blocks sshd accept for several minutes.
  security.pam.services.sshd.startSession = lib.mkForce false;

  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorPubkey ];
  };
}
